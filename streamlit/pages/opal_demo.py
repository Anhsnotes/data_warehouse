"""
OPAL Authorization Demo Page
Demonstrates role-based access control using OPAL/OPA policies.
"""

import streamlit as st
import pandas as pd
import os
import json
import logging
from typing import Optional, Dict, Any, List
from pathlib import Path

try:
    import httpx
    HTTPX_AVAILABLE = True
except ImportError:
    HTTPX_AVAILABLE = False

logger = logging.getLogger(__name__)


# =============================================================================
# USER DATA & ROLES (mirrors OPAL data)
# =============================================================================

USERS = {
    "admin@company.com": {
        "name": "System Administrator",
        "roles": ["admin"],
        "avatar": "👑"
    },
    "data.engineer@company.com": {
        "name": "Data Engineer",
        "roles": ["data_engineer"],
        "avatar": "🔧"
    },
    "senior.analyst@company.com": {
        "name": "Senior Data Analyst",
        "roles": ["analyst"],
        "avatar": "📊"
    },
    "junior.analyst@company.com": {
        "name": "Junior Data Analyst",
        "roles": ["viewer"],
        "avatar": "👁️"
    },
    "ceo@company.com": {
        "name": "Chief Executive Officer",
        "roles": ["executive"],
        "avatar": "🏢"
    },
    "sales.manager.west@company.com": {
        "name": "Sales Manager - West",
        "roles": ["sales_manager"],
        "avatar": "💼"
    },
    "hr.director@company.com": {
        "name": "HR Director",
        "roles": ["hr_manager"],
        "avatar": "👔"
    },
    "ops.manager@company.com": {
        "name": "Operations Manager",
        "roles": ["operations_manager"],
        "avatar": "⚙️"
    },
    "marketing.director@company.com": {
        "name": "Marketing Director",
        "roles": ["marketing_manager"],
        "avatar": "📢"
    },
}

# Dashboard permissions based on OPAL policies
DASHBOARD_PERMISSIONS = {
    "dashboard.sales": {
        "allowed_roles": ["admin", "data_engineer", "analyst", "viewer", "executive", "sales_manager"],
        "title": "Sales Dashboard",
        "icon": "💰",
        "description": "Revenue analytics, sales trends, and performance metrics"
    },
    "dashboard.hr": {
        "allowed_roles": ["admin", "data_engineer", "hr_manager", "executive"],
        "title": "HR Dashboard",
        "icon": "👔",
        "description": "Employee data, performance reviews, and workforce analytics"
    },
    "dashboard.operations": {
        "allowed_roles": ["admin", "data_engineer", "analyst", "viewer", "executive", "operations_manager"],
        "title": "Operations Dashboard",
        "icon": "⚙️",
        "description": "Inventory, supply chain, and production metrics"
    },
    "dashboard.customer_analytics": {
        "allowed_roles": ["admin", "data_engineer", "analyst", "executive", "sales_manager", "marketing_manager"],
        "title": "Customer Analytics",
        "icon": "👥",
        "description": "Customer segmentation, CLV, and behavior analysis"
    },
    "dashboard.product_inventory": {
        "allowed_roles": ["admin", "data_engineer", "analyst", "executive", "operations_manager"],
        "title": "Product & Inventory",
        "icon": "📦",
        "description": "Product performance and inventory management"
    },
    "dashboard.ai_assistant": {
        "allowed_roles": ["admin", "data_engineer", "analyst", "executive"],
        "title": "AI Assistant",
        "icon": "🤖",
        "description": "Natural language queries and AI-powered insights"
    },
}

# Data export permissions
EXPORT_PERMISSIONS = {
    "mart_sales": {
        "allowed_roles": ["admin", "data_engineer", "analyst", "executive", "sales_manager"],
        "title": "Sales Data Export",
        "icon": "📤"
    },
    "mart_customer_analytics": {
        "allowed_roles": ["admin", "data_engineer", "analyst", "executive"],
        "title": "Customer Data Export (PII)",
        "icon": "🔒",
        "requires_approval": True
    },
    "mart_operations": {
        "allowed_roles": ["admin", "data_engineer", "executive", "operations_manager"],
        "title": "Operations Data Export",
        "icon": "📊"
    },
}


# =============================================================================
# OPAL CLIENT (for live authorization)
# =============================================================================

class OPALClient:
    """Lightweight OPAL client for authorization checks."""
    
    def __init__(self, opa_url: Optional[str] = None):
        self.opa_url = opa_url or os.getenv('OPA_URL', 'http://localhost:8181')
        self._available = HTTPX_AVAILABLE
    
    def is_healthy(self) -> bool:
        """Check if OPA is healthy and responding."""
        if not self._available:
            return False
        try:
            with httpx.Client(timeout=2.0) as client:
                response = client.get(f"{self.opa_url}/health")
                return response.status_code == 200
        except Exception:
            return False
    
    def authorize(self, user: str, action: str, resource: str) -> Optional[bool]:
        """
        Check authorization via OPA.
        Returns None if OPA is unavailable (fallback to local policy).
        """
        if not self._available:
            return None
        
        try:
            with httpx.Client(timeout=2.0) as client:
                response = client.post(
                    f"{self.opa_url}/v1/data/datawarehouse/authz/allow",
                    json={"input": {"user": user, "action": action, "resource": resource}}
                )
                if response.status_code == 200:
                    return response.json().get("result", False)
        except Exception as e:
            logger.debug(f"OPA check failed: {e}")
        return None


def check_permission(user_email: str, action: str, resource: str, opal_client: Optional[OPALClient] = None) -> bool:
    """
    Check if user has permission for an action on a resource.
    Uses OPAL/OPA if available, falls back to local policy check.
    """
    # Try OPAL first
    if opal_client:
        result = opal_client.authorize(user_email, action, resource)
        if result is not None:
            return result
    
    # Fallback to local policy check
    user = USERS.get(user_email)
    if not user:
        return False
    
    user_roles = set(user.get("roles", []))
    
    # Admin has full access
    if "admin" in user_roles:
        return True
    
    # Check dashboard permissions
    if action == "view" and resource in DASHBOARD_PERMISSIONS:
        allowed_roles = set(DASHBOARD_PERMISSIONS[resource]["allowed_roles"])
        return bool(user_roles & allowed_roles)
    
    # Check export permissions
    if action == "export" and resource in EXPORT_PERMISSIONS:
        allowed_roles = set(EXPORT_PERMISSIONS[resource]["allowed_roles"])
        return bool(user_roles & allowed_roles)
    
    return False


# =============================================================================
# UI COMPONENTS
# =============================================================================

def render_access_badge(allowed: bool, compact: bool = False):
    """Render an access badge indicating allowed/denied status."""
    if allowed:
        if compact:
            return "✅"
        return st.success("✅ **ACCESS GRANTED**", icon="✅")
    else:
        if compact:
            return "🔒"
        return st.error("🔒 **ACCESS DENIED**", icon="🚫")


def render_dashboard_card(dashboard_id: str, dashboard_info: dict, allowed: bool, conn):
    """Render a dashboard card with access status."""
    
    with st.container():
        if allowed:
            # Fully visible card with data
            st.markdown(f"""
            <div style="
                background: linear-gradient(135deg, #1a1f36 0%, #252b48 100%);
                border-radius: 12px;
                padding: 20px;
                margin-bottom: 16px;
                border-left: 4px solid #10b981;
                box-shadow: 0 4px 15px rgba(0,0,0,0.2);
            ">
                <div style="display: flex; align-items: center; margin-bottom: 10px;">
                    <span style="font-size: 28px; margin-right: 12px;">{dashboard_info['icon']}</span>
                    <h3 style="margin: 0; color: #f8fafc; font-size: 18px;">{dashboard_info['title']}</h3>
                    <span style="margin-left: auto; background: #10b981; color: white; padding: 4px 12px; border-radius: 20px; font-size: 12px;">
                        ACCESSIBLE
                    </span>
                </div>
                <p style="color: #94a3b8; margin: 0; font-size: 14px;">{dashboard_info['description']}</p>
            </div>
            """, unsafe_allow_html=True)
            
            # Show sample data if available
            if conn and dashboard_id in ["dashboard.sales", "dashboard.operations", "dashboard.customer_analytics"]:
                render_sample_data(dashboard_id, conn)
        else:
            # Locked/blurred card
            st.markdown(f"""
            <div style="
                background: linear-gradient(135deg, #1f1f2e 0%, #2a2a3d 100%);
                border-radius: 12px;
                padding: 20px;
                margin-bottom: 16px;
                border-left: 4px solid #ef4444;
                box-shadow: 0 4px 15px rgba(0,0,0,0.2);
                opacity: 0.7;
                position: relative;
            ">
                <div style="
                    position: absolute;
                    top: 50%;
                    left: 50%;
                    transform: translate(-50%, -50%);
                    font-size: 48px;
                    opacity: 0.3;
                ">🔒</div>
                <div style="display: flex; align-items: center; margin-bottom: 10px; filter: blur(2px);">
                    <span style="font-size: 28px; margin-right: 12px;">{dashboard_info['icon']}</span>
                    <h3 style="margin: 0; color: #64748b; font-size: 18px;">{dashboard_info['title']}</h3>
                </div>
                <p style="color: #475569; margin: 0; font-size: 14px; filter: blur(2px);">{dashboard_info['description']}</p>
                <div style="margin-top: 12px; text-align: center;">
                    <span style="background: #ef4444; color: white; padding: 4px 12px; border-radius: 20px; font-size: 12px;">
                        🚫 ACCESS DENIED
                    </span>
                </div>
            </div>
            """, unsafe_allow_html=True)


def render_sample_data(dashboard_id: str, conn):
    """Render sample data for a dashboard."""
    try:
        with st.expander("📊 Preview Data", expanded=False):
            if dashboard_id == "dashboard.sales":
                with conn.cursor() as cur:
                    cur.execute("""
                        SELECT territory_name, COUNT(*) as orders, SUM(order_total)::numeric::integer as revenue
                        FROM mart_sales
                        WHERE territory_name IS NOT NULL
                        GROUP BY territory_name
                        ORDER BY revenue DESC
                        LIMIT 5
                    """)
                    df = pd.DataFrame(cur.fetchall(), columns=['Territory', 'Orders', 'Revenue'])
                    if not df.empty:
                        df['Revenue'] = df['Revenue'].apply(lambda x: f"${x:,}")
                        st.dataframe(df, use_container_width=True, hide_index=True)
            
            elif dashboard_id == "dashboard.operations":
                with conn.cursor() as cur:
                    cur.execute("""
                        SELECT category_name, SUM(orderqty) as quantity, COUNT(DISTINCT product_key) as products
                        FROM mart_sales
                        WHERE category_name IS NOT NULL
                        GROUP BY category_name
                        ORDER BY quantity DESC
                        LIMIT 5
                    """)
                    df = pd.DataFrame(cur.fetchall(), columns=['Category', 'Quantity Sold', 'Products'])
                    if not df.empty:
                        st.dataframe(df, use_container_width=True, hide_index=True)
            
            elif dashboard_id == "dashboard.customer_analytics":
                with conn.cursor() as cur:
                    cur.execute("""
                        SELECT customer_segment, COUNT(*) as customers, 
                               ROUND(AVG(lifetime_value)::numeric, 0)::integer as avg_clv
                        FROM mart_customer_analytics
                        WHERE customer_segment IS NOT NULL AND customer_segment != ''
                        GROUP BY customer_segment
                        ORDER BY avg_clv DESC
                        LIMIT 5
                    """)
                    df = pd.DataFrame(cur.fetchall(), columns=['Segment', 'Customers', 'Avg CLV'])
                    if not df.empty:
                        df['Avg CLV'] = df['Avg CLV'].apply(lambda x: f"${x:,}" if pd.notna(x) else "N/A")
                        st.dataframe(df, use_container_width=True, hide_index=True)
    except Exception as e:
        st.caption(f"Preview unavailable")


def render_export_section(user_email: str, opal_client: Optional[OPALClient]):
    """Render data export section with permission checks."""
    
    st.markdown("---")
    st.subheader("📤 Data Export Permissions")
    
    cols = st.columns(3)
    
    for idx, (resource, info) in enumerate(EXPORT_PERMISSIONS.items()):
        allowed = check_permission(user_email, "export", resource, opal_client)
        
        with cols[idx % 3]:
            if allowed:
                st.markdown(f"""
                <div style="
                    background: linear-gradient(135deg, #0f172a 0%, #1e293b 100%);
                    border-radius: 10px;
                    padding: 16px;
                    text-align: center;
                    border: 1px solid #10b981;
                ">
                    <div style="font-size: 32px;">{info['icon']}</div>
                    <div style="color: #f1f5f9; font-weight: 600; margin: 8px 0;">{info['title']}</div>
                    <div style="background: #10b981; color: white; padding: 6px 16px; border-radius: 6px; display: inline-block; font-size: 13px;">
                        ✅ Can Export
                    </div>
                </div>
                """, unsafe_allow_html=True)
            else:
                pii_note = " (Contains PII)" if info.get("requires_approval") else ""
                st.markdown(f"""
                <div style="
                    background: linear-gradient(135deg, #18181b 0%, #27272a 100%);
                    border-radius: 10px;
                    padding: 16px;
                    text-align: center;
                    border: 1px solid #3f3f46;
                    opacity: 0.6;
                ">
                    <div style="font-size: 32px; filter: grayscale(1);">{info['icon']}</div>
                    <div style="color: #71717a; font-weight: 600; margin: 8px 0;">{info['title']}{pii_note}</div>
                    <div style="background: #52525b; color: #a1a1aa; padding: 6px 16px; border-radius: 6px; display: inline-block; font-size: 13px;">
                        🔒 Restricted
                    </div>
                </div>
                """, unsafe_allow_html=True)


def render_permissions_matrix(user_email: str, opal_client: Optional[OPALClient]):
    """Render a permissions matrix showing all access rights."""
    
    st.markdown("---")
    st.subheader("📋 Full Permissions Matrix")
    
    user = USERS.get(user_email, {})
    user_roles = user.get("roles", [])
    
    # Build matrix data
    matrix_data = []
    
    for dashboard_id, info in DASHBOARD_PERMISSIONS.items():
        allowed = check_permission(user_email, "view", dashboard_id, opal_client)
        matrix_data.append({
            "Resource": f"{info['icon']} {info['title']}",
            "Type": "Dashboard",
            "Action": "view",
            "Access": "✅ Allowed" if allowed else "🚫 Denied",
        })
    
    for resource, info in EXPORT_PERMISSIONS.items():
        allowed = check_permission(user_email, "export", resource, opal_client)
        matrix_data.append({
            "Resource": f"{info['icon']} {info['title']}",
            "Type": "Export",
            "Action": "export",
            "Access": "✅ Allowed" if allowed else "🚫 Denied",
        })
    
    df = pd.DataFrame(matrix_data)
    
    # Style the dataframe
    def highlight_access(val):
        if "Allowed" in val:
            return 'background-color: #064e3b; color: #10b981'
        else:
            return 'background-color: #450a0a; color: #f87171'
    
    styled_df = df.style.applymap(highlight_access, subset=['Access'])
    st.dataframe(styled_df, use_container_width=True, hide_index=True)


# =============================================================================
# MAIN RENDER FUNCTION
# =============================================================================

def render(conn):
    """Main render function for the OPAL Demo page."""
    
    # Custom CSS for the page
    st.markdown("""
    <style>
    @import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;600&family=Space+Grotesk:wght@400;500;600;700&display=swap');
    
    .opal-header {
        background: linear-gradient(135deg, #0f172a 0%, #1e1b4b 50%, #312e81 100%);
        padding: 30px;
        border-radius: 16px;
        margin-bottom: 24px;
        border: 1px solid #4f46e5;
        box-shadow: 0 0 30px rgba(79, 70, 229, 0.3);
    }
    
    .opal-header h1 {
        font-family: 'Space Grotesk', sans-serif;
        color: #f8fafc;
        font-size: 2.2rem;
        margin: 0;
        text-shadow: 0 0 20px rgba(99, 102, 241, 0.5);
    }
    
    .opal-header p {
        color: #a5b4fc;
        font-size: 1rem;
        margin: 10px 0 0 0;
    }
    
    .profile-card {
        background: linear-gradient(135deg, #1e293b 0%, #0f172a 100%);
        border-radius: 12px;
        padding: 20px;
        border: 1px solid #334155;
        margin-bottom: 20px;
    }
    
    .profile-avatar {
        font-size: 48px;
        text-align: center;
        margin-bottom: 10px;
    }
    
    .profile-name {
        color: #f1f5f9;
        font-size: 1.2rem;
        font-weight: 600;
        text-align: center;
    }
    
    .profile-email {
        color: #64748b;
        font-size: 0.85rem;
        text-align: center;
        font-family: 'JetBrains Mono', monospace;
    }
    
    .role-badge {
        background: linear-gradient(135deg, #4f46e5 0%, #7c3aed 100%);
        color: white;
        padding: 4px 12px;
        border-radius: 20px;
        font-size: 12px;
        display: inline-block;
        margin: 4px;
    }
    
    .status-indicator {
        display: flex;
        align-items: center;
        gap: 8px;
        padding: 8px 12px;
        border-radius: 8px;
        margin-top: 16px;
    }
    
    .status-online {
        background: rgba(16, 185, 129, 0.1);
        border: 1px solid #10b981;
    }
    
    .status-offline {
        background: rgba(245, 158, 11, 0.1);
        border: 1px solid #f59e0b;
    }
    </style>
    """, unsafe_allow_html=True)
    
    # Header
    st.markdown("""
    <div class="opal-header">
        <h1>🛡️ OPAL Authorization Demo</h1>
        <p>Experience role-based access control (RBAC) powered by Open Policy Agent (OPA) and OPAL</p>
    </div>
    """, unsafe_allow_html=True)
    
    # Initialize OPAL client
    opal_client = OPALClient()
    opa_healthy = opal_client.is_healthy()
    
    # Sidebar: Profile Selection
    st.sidebar.markdown("---")
    st.sidebar.markdown("### 👤 Switch Profile")
    
    # Profile selector
    user_options = {email: f"{info['avatar']} {info['name']}" for email, info in USERS.items()}
    
    selected_user = st.sidebar.selectbox(
        "Select User Profile",
        options=list(USERS.keys()),
        format_func=lambda x: user_options[x],
        key="opal_user_select"
    )
    
    # Store in session state
    if 'current_user' not in st.session_state:
        st.session_state.current_user = selected_user
    st.session_state.current_user = selected_user
    
    user_info = USERS[selected_user]
    
    # Profile card in sidebar
    st.sidebar.markdown(f"""
    <div class="profile-card">
        <div class="profile-avatar">{user_info['avatar']}</div>
        <div class="profile-name">{user_info['name']}</div>
        <div class="profile-email">{selected_user}</div>
        <div style="text-align: center; margin-top: 12px;">
            {''.join([f'<span class="role-badge">{role}</span>' for role in user_info['roles']])}
        </div>
    </div>
    """, unsafe_allow_html=True)
    
    # OPA Status indicator
    if opa_healthy:
        st.sidebar.markdown("""
        <div class="status-indicator status-online">
            <span style="color: #10b981; font-size: 20px;">●</span>
            <span style="color: #10b981;">OPA Server Online</span>
        </div>
        """, unsafe_allow_html=True)
    else:
        st.sidebar.markdown("""
        <div class="status-indicator status-offline">
            <span style="color: #f59e0b; font-size: 20px;">●</span>
            <span style="color: #f59e0b;">Using Local Policies</span>
        </div>
        """, unsafe_allow_html=True)
    
    # Main content area
    col1, col2 = st.columns([2, 1])
    
    with col1:
        st.markdown(f"### 👋 Welcome, {user_info['name']}")
        st.markdown(f"""
        You are logged in as **{selected_user}** with the following role(s):
        **{', '.join(user_info['roles'])}**
        
        Based on your role, you have access to specific dashboards and features. 
        Components you don't have access to will appear locked or hidden.
        """)
    
    with col2:
        st.info(f"""
        **💡 Try switching profiles** in the sidebar to see how different roles 
        affect access to various components.
        """)
    
    # Dashboard Access Section
    st.markdown("---")
    st.subheader("📊 Dashboard Access")
    st.markdown("Each card below represents a dashboard. Your access is determined by OPAL policies.")
    
    # Create dashboard grid
    dashboard_items = list(DASHBOARD_PERMISSIONS.items())
    
    # First row (3 cards)
    cols = st.columns(3)
    for idx, (dashboard_id, dashboard_info) in enumerate(dashboard_items[:3]):
        with cols[idx]:
            allowed = check_permission(selected_user, "view", dashboard_id, opal_client)
            render_dashboard_card(dashboard_id, dashboard_info, allowed, conn)
    
    # Second row (3 cards)
    cols = st.columns(3)
    for idx, (dashboard_id, dashboard_info) in enumerate(dashboard_items[3:6]):
        with cols[idx]:
            allowed = check_permission(selected_user, "view", dashboard_id, opal_client)
            render_dashboard_card(dashboard_id, dashboard_info, allowed, conn)
    
    # Export permissions section
    render_export_section(selected_user, opal_client)
    
    # Permissions matrix
    render_permissions_matrix(selected_user, opal_client)
    
    # How it works section
    st.markdown("---")
    st.subheader("🔧 How OPAL Authorization Works")
    
    with st.expander("📖 Learn about the authorization flow", expanded=False):
        st.markdown("""
        ### Authorization Flow
        
        1. **User Request**: When a user tries to access a resource (dashboard, data export, etc.),
           the application sends an authorization request to OPA.
        
        2. **Policy Evaluation**: OPA evaluates the request against Rego policies that define:
           - Which roles can access which resources
           - What actions each role can perform
           - Row-level security filters for sensitive data
        
        3. **Decision**: OPA returns an `allow: true/false` decision based on the policy evaluation.
        
        4. **Enforcement**: The application enforces the decision by showing/hiding components.
        
        ### Sample Policy (Rego)
        
        ```rego
        # Allow access to sales dashboard for specific roles
        allow if {
            input.action == "view"
            input.resource == "dashboard.sales"
            {"sales_manager", "executive", "analyst"} & user_roles != set()
        }
        ```
        
        ### Key Components
        
        | Component | Description |
        |-----------|-------------|
        | **OPA** | Open Policy Agent - policy decision engine |
        | **OPAL** | Policy administration layer that syncs policies & data to OPA |
        | **Rego** | Declarative policy language used by OPA |
        | **Policy Data** | User roles, permissions, and resource metadata |
        """)
    
    # Role comparison table
    with st.expander("📊 Compare role permissions", expanded=False):
        st.markdown("### Role Permission Comparison")
        
        # Build comparison matrix
        comparison_data = []
        for email, user in USERS.items():
            row = {"User": f"{user['avatar']} {user['name']}", "Role(s)": ", ".join(user['roles'])}
            for dashboard_id, dashboard_info in DASHBOARD_PERMISSIONS.items():
                allowed = check_permission(email, "view", dashboard_id, None)
                row[dashboard_info['icon']] = "✅" if allowed else "❌"
            comparison_data.append(row)
        
        df = pd.DataFrame(comparison_data)
        st.dataframe(df, use_container_width=True, hide_index=True)
        
        st.caption("Column icons: 💰 Sales | 👔 HR | ⚙️ Operations | 👥 Customer | 📦 Inventory | 🤖 AI")
