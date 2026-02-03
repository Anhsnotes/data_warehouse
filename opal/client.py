"""
OPAL Access Control Client for Data Warehouse
Python client library for integrating OPAL authorization into applications.

Usage:
    from opal.client import OPALClient
    
    client = OPALClient()
    
    # Check if user can perform action
    if client.authorize(user="analyst@company.com", action="read", resource="mart_sales"):
        # Allow access
        pass
    
    # Get user's accessible tables
    tables = client.get_accessible_tables(user="analyst@company.com")
"""

import os
import json
import logging
from typing import Any, Dict, List, Optional
from functools import lru_cache
import httpx

logger = logging.getLogger(__name__)


class OPALClient:
    """Client for OPAL/OPA authorization."""
    
    def __init__(
        self,
        opa_url: Optional[str] = None,
        opal_server_url: Optional[str] = None,
        timeout: float = 5.0,
        cache_ttl: int = 60
    ):
        """
        Initialize the OPAL client.
        
        Args:
            opa_url: OPA server URL (default: http://localhost:8181)
            opal_server_url: OPAL server URL for data updates (default: http://localhost:7002)
            timeout: Request timeout in seconds
            cache_ttl: Cache time-to-live in seconds
        """
        self.opa_url = opa_url or os.getenv('OPA_URL', 'http://localhost:8181')
        self.opal_server_url = opal_server_url or os.getenv('OPAL_SERVER_URL', 'http://localhost:7002')
        self.timeout = timeout
        self.cache_ttl = cache_ttl
        self._client = httpx.Client(timeout=timeout)
    
    def __del__(self):
        """Cleanup HTTP client."""
        try:
            self._client.close()
        except Exception:
            pass
    
    def is_healthy(self) -> bool:
        """Check if OPA is healthy and responding."""
        try:
            response = self._client.get(f"{self.opa_url}/health")
            return response.status_code == 200
        except httpx.RequestError:
            return False
    
    def authorize(
        self,
        user: str,
        action: str,
        resource: str,
        context: Optional[Dict[str, Any]] = None
    ) -> bool:
        """
        Check if a user is authorized to perform an action on a resource.
        
        Args:
            user: User identifier (email or ID)
            action: Action to perform (read, write, delete, export, view, etc.)
            resource: Resource identifier (table name, dashboard name, etc.)
            context: Additional context for the authorization decision
        
        Returns:
            True if authorized, False otherwise
        """
        input_data = {
            "user": user,
            "action": action,
            "resource": resource,
        }
        
        if context:
            input_data.update(context)
        
        try:
            response = self._client.post(
                f"{self.opa_url}/v1/data/datawarehouse/authz/allow",
                json={"input": input_data}
            )
            
            if response.status_code == 200:
                result = response.json()
                return result.get("result", False)
            else:
                logger.error(f"OPA returned status {response.status_code}")
                return False
                
        except httpx.RequestError as e:
            logger.error(f"Failed to connect to OPA: {e}")
            # Fail closed - deny access on error
            return False
    
    def authorize_batch(
        self,
        user: str,
        requests: List[Dict[str, str]]
    ) -> Dict[str, bool]:
        """
        Check authorization for multiple action/resource pairs.
        
        Args:
            user: User identifier
            requests: List of {"action": str, "resource": str} dicts
        
        Returns:
            Dict mapping "action:resource" to authorization result
        """
        results = {}
        for req in requests:
            key = f"{req['action']}:{req['resource']}"
            results[key] = self.authorize(
                user=user,
                action=req['action'],
                resource=req['resource']
            )
        return results
    
    def get_user_roles(self, user: str) -> List[str]:
        """
        Get the roles assigned to a user.
        
        Args:
            user: User identifier
        
        Returns:
            List of role names
        """
        try:
            response = self._client.post(
                f"{self.opa_url}/v1/data/datawarehouse/authz/user_roles",
                json={"input": {"user": user}}
            )
            
            if response.status_code == 200:
                result = response.json()
                return list(result.get("result", []))
            return []
            
        except httpx.RequestError as e:
            logger.error(f"Failed to get user roles: {e}")
            return []
    
    def can_access_table(self, user: str, table: str) -> bool:
        """
        Check if user can access a specific table.
        
        Args:
            user: User identifier
            table: Table name
        
        Returns:
            True if user can access the table
        """
        return self.authorize(user=user, action="read", resource=table)
    
    def can_access_dashboard(self, user: str, dashboard: str) -> bool:
        """
        Check if user can access a specific dashboard.
        
        Args:
            user: User identifier
            dashboard: Dashboard name (e.g., "sales", "hr", "operations")
        
        Returns:
            True if user can access the dashboard
        """
        return self.authorize(user=user, action="view", resource=f"dashboard.{dashboard}")
    
    def can_export_data(self, user: str, resource: str, approval: bool = False) -> bool:
        """
        Check if user can export data from a resource.
        
        Args:
            user: User identifier
            resource: Resource to export
            approval: Whether the export has been approved (required for PII)
        
        Returns:
            True if user can export
        """
        return self.authorize(
            user=user,
            action="export",
            resource=resource,
            context={"approval": approval}
        )
    
    def get_accessible_tables(self, user: str) -> List[str]:
        """
        Get list of tables the user can access.
        
        Args:
            user: User identifier
        
        Returns:
            List of accessible table names
        """
        try:
            response = self._client.post(
                f"{self.opa_url}/v1/data/datawarehouse/data_access/accessible_tables",
                json={"input": {"user": user, "user_roles": self.get_user_roles(user)}}
            )
            
            if response.status_code == 200:
                result = response.json()
                return list(result.get("result", []))
            return []
            
        except httpx.RequestError as e:
            logger.error(f"Failed to get accessible tables: {e}")
            return []
    
    def get_row_filter(self, user: str, table: str) -> Optional[str]:
        """
        Get the row-level security filter for a user and table.
        
        Args:
            user: User identifier
            table: Table name
        
        Returns:
            SQL WHERE clause for row filtering, or None if no filter needed
        """
        try:
            response = self._client.post(
                f"{self.opa_url}/v1/data/datawarehouse/data_access/row_filter_condition",
                json={
                    "input": {
                        "user": user,
                        "table": table,
                        "user_roles": self.get_user_roles(user)
                    }
                }
            )
            
            if response.status_code == 200:
                result = response.json()
                filter_condition = result.get("result")
                if filter_condition and filter_condition != "1=1":
                    return filter_condition
            return None
            
        except httpx.RequestError as e:
            logger.error(f"Failed to get row filter: {e}")
            return None
    
    def get_audit_metadata(
        self,
        user: str,
        action: str,
        resource: str
    ) -> Dict[str, Any]:
        """
        Get audit metadata for an authorization decision.
        
        Args:
            user: User identifier
            action: Action performed
            resource: Resource accessed
        
        Returns:
            Audit metadata dict
        """
        try:
            response = self._client.post(
                f"{self.opa_url}/v1/data/datawarehouse/authz/audit_metadata",
                json={
                    "input": {
                        "user": user,
                        "action": action,
                        "resource": resource
                    }
                }
            )
            
            if response.status_code == 200:
                result = response.json()
                return result.get("result", {})
            return {}
            
        except httpx.RequestError as e:
            logger.error(f"Failed to get audit metadata: {e}")
            return {}


class OPALClientAsync:
    """Async client for OPAL/OPA authorization."""
    
    def __init__(
        self,
        opa_url: Optional[str] = None,
        timeout: float = 5.0
    ):
        self.opa_url = opa_url or os.getenv('OPA_URL', 'http://localhost:8181')
        self.timeout = timeout
    
    async def authorize(
        self,
        user: str,
        action: str,
        resource: str,
        context: Optional[Dict[str, Any]] = None
    ) -> bool:
        """Async version of authorize."""
        input_data = {
            "user": user,
            "action": action,
            "resource": resource,
        }
        
        if context:
            input_data.update(context)
        
        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                response = await client.post(
                    f"{self.opa_url}/v1/data/datawarehouse/authz/allow",
                    json={"input": input_data}
                )
                
                if response.status_code == 200:
                    result = response.json()
                    return result.get("result", False)
                return False
                
        except httpx.RequestError as e:
            logger.error(f"Failed to connect to OPA: {e}")
            return False


# Decorator for protecting functions with authorization
def require_authorization(action: str, resource: str):
    """
    Decorator to require authorization for a function.
    
    Usage:
        @require_authorization(action="read", resource="mart_sales")
        def get_sales_data(user: str):
            ...
    """
    def decorator(func):
        def wrapper(*args, **kwargs):
            # Try to get user from kwargs or first arg
            user = kwargs.get('user') or (args[0] if args else None)
            if not user:
                raise ValueError("User must be provided for authorization")
            
            client = OPALClient()
            if not client.authorize(user=user, action=action, resource=resource):
                raise PermissionError(
                    f"User {user} is not authorized to {action} {resource}"
                )
            
            return func(*args, **kwargs)
        return wrapper
    return decorator


# Example usage and testing
if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    
    client = OPALClient()
    
    print("Testing OPAL Client...")
    print(f"OPA Health: {client.is_healthy()}")
    
    # Test authorization
    test_cases = [
        ("admin@company.com", "read", "mart_sales"),
        ("senior.analyst@company.com", "read", "mart_sales"),
        ("junior.analyst@company.com", "export", "mart_sales"),
        ("sales.manager.west@company.com", "view", "dashboard.sales"),
    ]
    
    print("\nAuthorization Tests:")
    for user, action, resource in test_cases:
        result = client.authorize(user=user, action=action, resource=resource)
        status = "✓ ALLOWED" if result else "✗ DENIED"
        print(f"  {user} -> {action} {resource}: {status}")
