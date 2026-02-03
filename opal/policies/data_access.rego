# Data Access Policy for Data Warehouse Tables
# Fine-grained table and column level access control

package datawarehouse.data_access

import future.keywords.if
import future.keywords.in
import future.keywords.contains

# =============================================================================
# TABLE-LEVEL ACCESS CONTROL
# =============================================================================

# Define accessible tables per role
accessible_tables[table] if {
    some role in input.user_roles
    some table in data.table_permissions[role].tables
}

# Check if user can access a specific table
can_access_table(table_name) if {
    table_name in accessible_tables
}

# Staging tables access
staging_tables := {
    "stg_humanresources__department",
    "stg_humanresources__employee",
    "stg_humanresources__employeedepartmenthistory",
    "stg_humanresources__employeepayhistory",
    "stg_person__address",
    "stg_person__businessentity",
    "stg_person__businessentityaddress",
    "stg_person__businessentitycontact",
    "stg_person__contacttype",
    "stg_person__countryregion",
    "stg_person__emailaddress",
    "stg_person__password",
    "stg_person__person",
    "stg_person__personphone",
    "stg_person__phonenumbertype",
    "stg_person__stateprovince",
    "stg_production__billofmaterials",
    "stg_production__culture",
    "stg_production__document",
    "stg_production__illustration",
    "stg_production__location",
    "stg_production__product",
    "stg_production__productcategory",
    "stg_production__productcosthistory",
    "stg_production__productdescription",
    "stg_production__productdocument",
    "stg_production__productinventory",
    "stg_production__productlistpricehistory",
    "stg_production__productmodel",
    "stg_production__productmodelillustration",
    "stg_production__productmodelproductdescriptionculture",
    "stg_production__productphoto",
    "stg_production__productproductphoto",
    "stg_production__productreview",
    "stg_production__productsubcategory",
    "stg_production__scrapreason",
    "stg_production__transactionhistory",
    "stg_production__transactionhistoryarchive",
    "stg_production__unitmeasure",
    "stg_production__workorder",
    "stg_production__workorderrouting",
    "stg_purchasing__productvendor",
    "stg_purchasing__purchaseorderdetail",
    "stg_purchasing__purchaseorderheader",
    "stg_purchasing__shipmethod",
    "stg_purchasing__vendor",
    "stg_sales__countryregioncurrency",
    "stg_sales__creditcard",
    "stg_sales__currency",
    "stg_sales__currencyrate",
    "stg_sales__customer",
    "stg_sales__personcreditcard",
    "stg_sales__salesorderdetail",
    "stg_sales__salesorderheader",
    "stg_sales__salesorderheadersalesreason",
    "stg_sales__salesperson",
    "stg_sales__salespersonquotahistory",
    "stg_sales__salesreason",
    "stg_sales__salestaxrate",
    "stg_sales__salesterritory",
    "stg_sales__salesterritoryhistory",
    "stg_sales__shoppingcartitem",
    "stg_sales__specialoffer",
    "stg_sales__specialofferproduct",
    "stg_sales__store",
}

# Mart tables access
mart_tables := {
    "mart_sales",
    "mart_customer_analytics",
    "mart_product_analytics",
    "mart_operations",
    "mart_employee_territory_performance",
    "mart_metrics",
}

# Dimension tables
dimension_tables := {
    "dim_customer",
    "dim_date",
    "dim_employee",
    "dim_metric",
    "dim_product",
    "dim_territory",
    "dim_vendor",
}

# Fact tables
fact_tables := {
    "fact_employee_quota",
    "fact_global_metrics",
    "fact_inventory",
    "fact_purchase_order",
    "fact_sales_order",
    "fact_sales_order_line",
    "fact_work_order",
}

# =============================================================================
# COLUMN-LEVEL ACCESS CONTROL
# =============================================================================

# Sensitive columns that require special access
sensitive_columns := {
    "salary",
    "ssn",
    "credit_card_number",
    "password_hash",
    "password_salt",
    "email",
    "phone",
    "address",
    "bank_account",
}

# Check if column is sensitive
is_sensitive_column(column) if {
    some col in sensitive_columns
    contains(lower(column), col)
}

# Columns accessible by role
allowed_columns[column] if {
    input.table in accessible_tables
    some column in data.column_permissions[input.table].columns
    not is_sensitive_column(column)
}

# Allow sensitive columns only for authorized roles
allowed_columns[column] if {
    input.table in accessible_tables
    some column in data.column_permissions[input.table].columns
    is_sensitive_column(column)
    can_access_sensitive_data
}

can_access_sensitive_data if {
    "data_engineer" in input.user_roles
}

can_access_sensitive_data if {
    "admin" in input.user_roles
}

can_access_sensitive_data if {
    "hr_manager" in input.user_roles
    startswith(input.table, "stg_humanresources")
}

# =============================================================================
# ROW-LEVEL SECURITY
# =============================================================================

# Filter condition for territory-based access
row_filter_condition := condition if {
    "sales_manager" in input.user_roles
    input.table in mart_tables
    condition := sprintf("territory_id IN (%s)", [concat(", ", data.users[input.user].territories)])
}

# Filter condition for department-based access
row_filter_condition := condition if {
    "hr_manager" in input.user_roles
    startswith(input.table, "stg_humanresources")
    condition := sprintf("department_id IN (%s)", [concat(", ", data.users[input.user].departments)])
}

# No filter for admin
row_filter_condition := "1=1" if {
    "admin" in input.user_roles
}

# No filter for full data access roles
row_filter_condition := "1=1" if {
    {"data_engineer", "analyst", "executive"} & {r | some r in input.user_roles} != set()
}

# =============================================================================
# DATA MASKING RULES
# =============================================================================

# Define masking rules for sensitive data
mask_rule(column) := rule if {
    is_sensitive_column(column)
    not can_access_sensitive_data
    column == "email"
    rule := "REGEXP_REPLACE(email, '(.).*@', '\\1***@')"
}

mask_rule(column) := rule if {
    is_sensitive_column(column)
    not can_access_sensitive_data
    column == "phone"
    rule := "CONCAT('***-***-', RIGHT(phone, 4))"
}

mask_rule(column) := rule if {
    is_sensitive_column(column)
    not can_access_sensitive_data
    column == "credit_card_number"
    rule := "CONCAT('****-****-****-', RIGHT(credit_card_number, 4))"
}

mask_rule(column) := column if {
    not is_sensitive_column(column)
}

mask_rule(column) := column if {
    is_sensitive_column(column)
    can_access_sensitive_data
}

# =============================================================================
# QUERY REWRITING
# =============================================================================

# Generate secure query with filters and masking
secure_query := query if {
    columns := [mask_rule(c) | some c in input.columns]
    column_list := concat(", ", columns)
    query := sprintf("SELECT %s FROM %s WHERE %s", [column_list, input.table, row_filter_condition])
}
