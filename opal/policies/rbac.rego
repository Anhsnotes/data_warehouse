# OPAL Role-Based Access Control Policy for Data Warehouse
# This policy enforces fine-grained access control for data warehouse resources

package datawarehouse.authz

import future.keywords.if
import future.keywords.in
import future.keywords.contains

# Default deny all access
default allow := false

# =============================================================================
# MAIN AUTHORIZATION RULE
# =============================================================================

# Allow access if user has required permission
allow if {
    some role in user_roles
    some permission in data.roles[role].permissions
    permission_matches(permission, input.action, input.resource)
}

# Allow admin users full access
allow if {
    "admin" in user_roles
}

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

# Get user roles from data
user_roles contains role if {
    some role in data.users[input.user].roles
}

# Check if permission matches the requested action and resource
permission_matches(permission, action, resource) if {
    permission.action == action
    permission.resource == resource
}

# Wildcard resource matching
permission_matches(permission, action, resource) if {
    permission.action == action
    permission.resource == "*"
}

# Wildcard action matching
permission_matches(permission, action, resource) if {
    permission.action == "*"
    permission.resource == resource
}

# =============================================================================
# DATABASE ACCESS RULES
# =============================================================================

# Allow read access to staging tables for analysts
allow if {
    input.action == "read"
    startswith(input.resource, "staging.")
    "analyst" in user_roles
}

# Allow read access to mart tables for analysts and viewers
allow if {
    input.action == "read"
    startswith(input.resource, "mart_")
    {"analyst", "viewer"} & user_roles != set()
}

# Allow write access to staging tables for data engineers
allow if {
    input.action in ["read", "write", "create", "delete"]
    startswith(input.resource, "staging.")
    "data_engineer" in user_roles
}

# Allow full access to intermediate tables for data engineers
allow if {
    input.action in ["read", "write", "create", "delete"]
    startswith(input.resource, "intermediate.")
    "data_engineer" in user_roles
}

# =============================================================================
# DASHBOARD ACCESS RULES
# =============================================================================

# Allow access to specific dashboards based on role
allow if {
    input.action == "view"
    input.resource == "dashboard.sales"
    {"sales_manager", "executive", "analyst"} & user_roles != set()
}

allow if {
    input.action == "view"
    input.resource == "dashboard.hr"
    {"hr_manager", "executive"} & user_roles != set()
}

allow if {
    input.action == "view"
    input.resource == "dashboard.operations"
    {"operations_manager", "executive", "analyst"} & user_roles != set()
}

allow if {
    input.action == "view"
    input.resource == "dashboard.customer_analytics"
    {"marketing_manager", "sales_manager", "executive", "analyst"} & user_roles != set()
}

allow if {
    input.action == "view"
    input.resource == "dashboard.ai_assistant"
    {"analyst", "data_engineer", "executive"} & user_roles != set()
}

# =============================================================================
# API ACCESS RULES
# =============================================================================

# Allow API read access for authenticated users with api_read permission
allow if {
    input.action == "api.read"
    "api_user" in user_roles
}

# Allow API write access for service accounts
allow if {
    input.action == "api.write"
    "service_account" in user_roles
}

# =============================================================================
# DATA EXPORT RULES
# =============================================================================

# Restrict data export to authorized roles only
allow if {
    input.action == "export"
    {"data_engineer", "analyst", "executive"} & user_roles != set()
    not contains_pii(input.resource)
}

# PII data export requires additional approval
allow if {
    input.action == "export"
    contains_pii(input.resource)
    "data_engineer" in user_roles
    input.approval == true
}

# Check if resource contains PII
contains_pii(resource) if {
    pii_tables := ["customer", "employee", "person"]
    some table in pii_tables
    contains(lower(resource), table)
}

# =============================================================================
# QUERY COMPLEXITY LIMITS
# =============================================================================

# Deny queries that are too complex for certain roles
deny[msg] if {
    input.action == "query"
    "viewer" in user_roles
    input.query_cost > 100
    msg := "Query too complex for viewer role. Maximum query cost: 100"
}

deny[msg] if {
    input.action == "query"
    "analyst" in user_roles
    input.query_cost > 1000
    msg := "Query too complex for analyst role. Maximum query cost: 1000"
}

# =============================================================================
# TIME-BASED ACCESS RULES
# =============================================================================

# Allow certain operations only during business hours
allow if {
    input.action == "write"
    input.resource == "production_data"
    is_business_hours
    "data_engineer" in user_roles
}

is_business_hours if {
    now := time.now_ns()
    hour := time.clock([now, "America/Los_Angeles"])[0]
    hour >= 9
    hour < 18
}

# =============================================================================
# AUDIT LOGGING METADATA
# =============================================================================

# Generate audit metadata for allowed actions
audit_metadata := {
    "user": input.user,
    "action": input.action,
    "resource": input.resource,
    "timestamp": time.now_ns(),
    "allowed": allow,
    "roles": user_roles,
}
