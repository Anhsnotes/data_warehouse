#!/usr/bin/env python3
"""
OPAL Data Fetcher Service
Syncs authorization data from the data warehouse database to OPAL.

This service periodically fetches user, role, and permission data from the
PostgreSQL database and pushes it to the OPAL server for real-time policy updates.
"""

import json
import os
import time
import logging
from typing import Any, Dict, List, Optional

import httpx
import psycopg2
from psycopg2.extras import RealDictCursor
import schedule

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('opal-data-fetcher')

# Configuration from environment
DATABASE_URL = os.getenv('DATABASE_URL', 'postgresql://postgres:postgres@localhost:5432/data_warehouse')
OPAL_SERVER_URL = os.getenv('OPAL_SERVER_URL', 'http://localhost:7002')
OPAL_CLIENT_TOKEN = os.getenv('OPAL_CLIENT_TOKEN', '')
SYNC_INTERVAL = int(os.getenv('SYNC_INTERVAL', '60'))


def get_db_connection():
    """Create a database connection."""
    try:
        conn = psycopg2.connect(DATABASE_URL, cursor_factory=RealDictCursor)
        return conn
    except Exception as e:
        logger.error(f"Failed to connect to database: {e}")
        return None


def fetch_users_from_db() -> List[Dict[str, Any]]:
    """
    Fetch user data from the data warehouse.
    Customize this query based on your user management setup.
    """
    conn = get_db_connection()
    if not conn:
        return []
    
    try:
        with conn.cursor() as cur:
            # Example: Fetch from a users table if it exists
            # Modify this query based on your actual schema
            cur.execute("""
                SELECT 
                    'user_' || COALESCE(businessentityid::text, '0') as user_id,
                    COALESCE(firstname || ' ' || lastname, 'Unknown') as name,
                    COALESCE(emailaddress, '') as email,
                    true as active
                FROM person.person p
                LEFT JOIN person.emailaddress e ON p.businessentityid = e.businessentityid
                WHERE p.persontype IN ('EM', 'SP')  -- Employees and Sales persons
                LIMIT 100
            """)
            users = cur.fetchall()
            return [dict(user) for user in users]
    except psycopg2.Error as e:
        logger.warning(f"Could not fetch users from database: {e}")
        return []
    finally:
        conn.close()


def fetch_territories_from_db() -> Dict[str, List[str]]:
    """
    Fetch territory assignments for sales personnel.
    """
    conn = get_db_connection()
    if not conn:
        return {}
    
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT 
                    sp.businessentityid,
                    array_agg(DISTINCT sth.territoryid::text) as territories
                FROM sales.salesperson sp
                LEFT JOIN sales.salesterritoryhistory sth 
                    ON sp.businessentityid = sth.businessentityid
                WHERE sth.enddate IS NULL  -- Current assignments only
                GROUP BY sp.businessentityid
            """)
            results = cur.fetchall()
            return {
                f"user_{row['businessentityid']}": row['territories'] 
                for row in results if row['territories']
            }
    except psycopg2.Error as e:
        logger.warning(f"Could not fetch territories: {e}")
        return {}
    finally:
        conn.close()


def fetch_departments_from_db() -> Dict[str, List[str]]:
    """
    Fetch department assignments for employees.
    """
    conn = get_db_connection()
    if not conn:
        return {}
    
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT 
                    edh.businessentityid,
                    array_agg(DISTINCT edh.departmentid::text) as departments
                FROM humanresources.employeedepartmenthistory edh
                WHERE edh.enddate IS NULL  -- Current assignments only
                GROUP BY edh.businessentityid
            """)
            results = cur.fetchall()
            return {
                f"user_{row['businessentityid']}": row['departments'] 
                for row in results if row['departments']
            }
    except psycopg2.Error as e:
        logger.warning(f"Could not fetch departments: {e}")
        return {}
    finally:
        conn.close()


def load_static_data() -> Dict[str, Any]:
    """Load static role and user data from JSON files."""
    data = {}
    
    # Load roles
    try:
        with open('/app/data/roles.json', 'r') as f:
            roles_data = json.load(f)
            data['roles'] = roles_data.get('roles', {})
    except FileNotFoundError:
        logger.warning("roles.json not found, using empty roles")
        data['roles'] = {}
    
    # Load users
    try:
        with open('/app/data/users.json', 'r') as f:
            users_data = json.load(f)
            data['users'] = users_data.get('users', {})
    except FileNotFoundError:
        logger.warning("users.json not found, using empty users")
        data['users'] = {}
    
    # Load table permissions
    try:
        with open('/app/data/table_permissions.json', 'r') as f:
            table_data = json.load(f)
            data['table_permissions'] = table_data.get('table_permissions', {})
    except FileNotFoundError:
        logger.warning("table_permissions.json not found")
        data['table_permissions'] = {}
    
    return data


def enrich_data_from_db(data: Dict[str, Any]) -> Dict[str, Any]:
    """Enrich static data with dynamic data from the database."""
    
    # Fetch territory and department assignments
    territories = fetch_territories_from_db()
    departments = fetch_departments_from_db()
    
    # Merge territory data
    for user_id, user_territories in territories.items():
        if user_id in data.get('users', {}):
            data['users'][user_id]['territories'] = user_territories
    
    # Merge department data
    for user_id, user_departments in departments.items():
        if user_id in data.get('users', {}):
            data['users'][user_id]['departments'] = user_departments
    
    return data


def push_data_to_opal(data: Dict[str, Any]) -> bool:
    """Push authorization data to OPAL server."""
    try:
        headers = {
            'Content-Type': 'application/json',
        }
        
        if OPAL_CLIENT_TOKEN:
            headers['Authorization'] = f'Bearer {OPAL_CLIENT_TOKEN}'
        
        # Push data update to OPAL
        response = httpx.post(
            f"{OPAL_SERVER_URL}/data/config",
            json={
                "entries": [
                    {
                        "url": "data:application/json," + json.dumps(data),
                        "topics": ["policy_data"],
                        "dst_path": ""
                    }
                ]
            },
            headers=headers,
            timeout=30.0
        )
        
        if response.status_code == 200:
            logger.info("Successfully pushed data to OPAL server")
            return True
        else:
            logger.error(f"Failed to push data to OPAL: {response.status_code} - {response.text}")
            return False
            
    except httpx.RequestError as e:
        logger.error(f"Network error pushing data to OPAL: {e}")
        return False


def sync_data():
    """Main sync function - loads and pushes authorization data."""
    logger.info("Starting data sync...")
    
    # Load static data from files
    data = load_static_data()
    
    # Enrich with dynamic database data
    data = enrich_data_from_db(data)
    
    # Push to OPAL
    success = push_data_to_opal(data)
    
    if success:
        logger.info(f"Data sync completed. Users: {len(data.get('users', {}))}, Roles: {len(data.get('roles', {}))}")
    else:
        logger.warning("Data sync completed with errors")


def main():
    """Main entry point."""
    logger.info(f"OPAL Data Fetcher starting...")
    logger.info(f"OPAL Server URL: {OPAL_SERVER_URL}")
    logger.info(f"Sync interval: {SYNC_INTERVAL} seconds")
    
    # Initial sync
    time.sleep(5)  # Wait for services to be ready
    sync_data()
    
    # Schedule periodic syncs
    schedule.every(SYNC_INTERVAL).seconds.do(sync_data)
    
    # Run the scheduler
    while True:
        schedule.run_pending()
        time.sleep(1)


if __name__ == '__main__':
    main()
