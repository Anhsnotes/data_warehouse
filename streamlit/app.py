"""
AdventureWorks Analytics Dashboard
Multi-page Streamlit application for comprehensive business analytics
"""

import streamlit as st
import pandas as pd
import psycopg2
from datetime import datetime
import plotly.express as px
import plotly.graph_objects as go
import folium
from streamlit_folium import st_folium

# Page configuration
st.set_page_config(
    page_title="AdventureWorks Analytics",
    page_icon="📊",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Database connection function
@st.cache_resource
def get_db_connection():
    """Create and return a database connection"""
    import os
    
    # Use environment variable or default to localhost for local development
    # In Docker, this will be set to "postgres" via docker-compose
    db_host = os.getenv("DB_HOST", "localhost")
    db_name = os.getenv("DB_NAME", "data_warehouse")
    db_user = os.getenv("DB_USER", "postgres")
    db_password = os.getenv("DB_PASSWORD", "postgres")
    db_port = os.getenv("DB_PORT", "5432")
    
    try:
        conn = psycopg2.connect(
            host=db_host,
            database=db_name,
            user=db_user,
            password=db_password,
            port=int(db_port),
            options="-c search_path=dbt,public"
        )
        return conn
    except Exception as e:
        st.error(f"Database connection error: {e}")
        st.info(f"Attempted to connect to: {db_host}:{db_port}/{db_name}")
        st.info("💡 Tip: If running locally, ensure PostgreSQL is running and accessible on localhost:5432")
        return None

# Get report date (max sales transaction date)
@st.cache_data(ttl=3600)  # Cache for 1 hour
def get_report_date(_conn):
    """Get the maximum order date from sales transactions as the report date"""
    if _conn is None:
        return None
    try:
        with _conn.cursor() as cur:
            cur.execute("SELECT MAX(order_date) FROM mart_sales")
            result = cur.fetchone()
            return result[0] if result and result[0] else None
    except Exception:
        return None

def show_report_date_note(conn):
    """Display a note about the report date on each page"""
    report_date = get_report_date(conn)
    if report_date:
        st.info(f"📅 **Report Date:** All analyses are based on data up to {report_date.strftime('%B %d, %Y')} (most recent sales transaction date).")
    else:
        st.warning("⚠️ Unable to determine report date from sales data.")

def format_dataframe(df):
    """Format dataframe numbers for easy reading: currency with $, numbers with comma separator, 0 decimals"""
    if df.empty:
        return df
    
    df_formatted = df.copy()
    
    # Currency-related column patterns
    currency_patterns = ['revenue', 'price', 'cost', 'value', 'clv', 'amount', 'total', 'profit', 'margin', 
                        'pay', 'quota', 'sales', 'purchase', 'inventory_value', 'lifetime_value', 
                        'order_total', 'line_amount', 'subtotal', 'taxamt', 'freight', 'totaldue']
    
    # Percentage columns (keep as is, but ensure numeric)
    percent_patterns = ['percent', 'percentage', '%', 'rate', 'ratio', 'achievement', 'margin', 'elasticity']
    
    # Count/quantity columns
    count_patterns = ['count', 'quantity', 'orders', 'qty', 'number', 'days', 'hours', 'years']
    
    for col in df_formatted.columns:
        # Skip non-numeric columns
        if df_formatted[col].dtype not in ['int64', 'float64', 'Int64', 'Float64']:
            # Try to convert to numeric if possible
            numeric_series = pd.to_numeric(df_formatted[col], errors='coerce')
            if numeric_series.notna().any():
                df_formatted[col] = numeric_series
            else:
                continue
        
        col_lower = col.lower()
        
        # Check if it's a currency column
        is_currency = any(pattern in col_lower for pattern in currency_patterns)
        # Check if it's a percentage column
        is_percent = any(pattern in col_lower for pattern in percent_patterns)
        # Check if it's a count/quantity column
        is_count = any(pattern in col_lower for pattern in count_patterns)
        
        if is_currency:
            # Format as currency: $X,XXX
            df_formatted[col] = df_formatted[col].apply(
                lambda x: f"${x:,.0f}" if pd.notna(x) and not pd.isnull(x) else ""
            )
        elif is_percent:
            # Format as percentage: X,XXX% (if not already formatted)
            if '%' not in str(df_formatted[col].iloc[0] if not df_formatted[col].empty else ''):
                df_formatted[col] = df_formatted[col].apply(
                    lambda x: f"{x:,.0f}%" if pd.notna(x) and not pd.isnull(x) else ""
                )
        elif is_count or df_formatted[col].dtype in ['int64', 'Int64']:
            # Format as integer with comma: X,XXX
            df_formatted[col] = df_formatted[col].apply(
                lambda x: f"{x:,.0f}" if pd.notna(x) and not pd.isnull(x) else ""
            )
        else:
            # Format other numeric columns as integer with comma: X,XXX
            df_formatted[col] = df_formatted[col].apply(
                lambda x: f"{x:,.0f}" if pd.notna(x) and not pd.isnull(x) else ""
            )
    
    return df_formatted

# Custom CSS
st.markdown("""
    <style>
    .main-header {
        font-size: 2.5rem;
        font-weight: bold;
        color: #1f77b4;
        margin-bottom: 1rem;
    }
    .metric-card {
        background-color: #f0f2f6;
        padding: 1rem;
        border-radius: 0.5rem;
        border-left: 4px solid #1f77b4;
    }
    /* Hide Streamlit's default page navigation links */
    [data-testid="stSidebarNav"] {
        display: none !important;
    }
    nav[data-testid="stSidebarNav"] {
        display: none !important;
    }
    section[data-testid="stSidebarNav"] {
        display: none !important;
    }
    </style>
""", unsafe_allow_html=True)

# Main page
st.markdown('<h1 class="main-header">📊 AdventureWorks Analytics Dashboard</h1>', unsafe_allow_html=True)
st.markdown("---")

# Sidebar navigation
st.sidebar.title("📑 Navigation")
st.sidebar.markdown("### Analytics Pages")

# Page selection
page = st.sidebar.radio(
    "Select Analytics Category",
    [
        "🏠 Overview",
        "🤖 AI Assistant",
        "💰 Sales & Revenue",
        "📦 Product & Inventory",
        "👥 Customer Analytics",
        "👔 HR & Employee Performance",
        "⚙️ Operations & Supply Chain",
        "🔮 Advanced Analytics",
        "🛡️ OPAL Authorization Demo"
    ],
    index=0
)

# Database connection
conn = get_db_connection()

if conn is None:
    st.error("⚠️ Unable to connect to database. Please ensure PostgreSQL is running.")
    st.stop()

# Overview Page
if page == "🏠 Overview":
    st.header("📊 Dashboard Overview")
    st.markdown("Welcome to the AdventureWorks Analytics Dashboard. Select an analytics category from the sidebar to explore insights.")
    show_report_date_note(conn)
    
    col1, col2, col3, col4 = st.columns(4)
    
    # Key metrics from mart_sales
    try:
        with conn.cursor() as cur:
            # Total Revenue
            cur.execute("""
                SELECT 
                    COUNT(DISTINCT salesorderid) as total_orders,
                    SUM(order_total) as total_revenue,
                    COUNT(DISTINCT customer_key) as total_customers,
                    COUNT(DISTINCT product_key) as total_products
                FROM mart_sales
            """)
            metrics = cur.fetchone()
            
            with col1:
                st.metric(
                    label="Total Orders",
                    value=f"{metrics[0]:,}" if metrics[0] else "0",
                )
            
            with col2:
                st.metric(
                    label="Total Revenue",
                    value=f"${metrics[1]:,.2f}" if metrics[1] else "$0",
                )
            
            with col3:
                st.metric(
                    label="Total Customers",
                    value=f"{metrics[2]:,}" if metrics[2] else "0",
                )
            
            with col4:
                st.metric(
                    label="Total Products",
                    value=f"{metrics[3]:,}" if metrics[3] else "0",
                )
    except Exception as e:
        st.error(f"Error loading metrics: {e}")
    
    st.markdown("---")
    
    # Quick insights
    col1, col2 = st.columns(2)
    
    with col1:
        st.subheader("📈 Revenue Trend Over Time")
        try:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT 
                        order_year,
                        order_month,
                        SUM(order_total) as monthly_revenue
                    FROM mart_sales
                    GROUP BY order_year, order_month
                    ORDER BY order_year, order_month
                """)
                revenue_data = pd.DataFrame(cur.fetchall(), columns=['Year', 'Month', 'Revenue'])
                if not revenue_data.empty:
                    revenue_data['Date'] = pd.to_datetime(revenue_data[['Year', 'Month']].assign(Day=1))
                    fig = px.line(revenue_data, x='Date', y='Revenue', 
                                 title='Monthly Revenue Trend',
                                 labels={'Revenue': 'Revenue ($)', 'Date': 'Month'})
                    st.plotly_chart(fig, use_container_width=True)
                else:
                    st.info("No data available")
        except Exception as e:
            st.error(f"Error loading revenue trend: {e}")
    
    with col2:
        st.subheader("🏆 Top 5 Products by Revenue")
        try:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT 
                        product_name,
                        SUM(net_line_amount) as total_revenue
                    FROM mart_sales
                    GROUP BY product_name
                    ORDER BY total_revenue DESC
                    LIMIT 5
                """)
                top_products = pd.DataFrame(cur.fetchall(), columns=['Product', 'Revenue'])
                if not top_products.empty:
                    fig = px.bar(top_products, x='Revenue', y='Product', 
                                orientation='h',
                                title='Top Products by Revenue',
                                labels={'Revenue': 'Revenue ($)', 'Product': 'Product Name'})
                    fig.update_layout(yaxis={'categoryorder': 'total ascending'})
                    st.plotly_chart(fig, use_container_width=True)
                else:
                    st.info("No data available")
        except Exception as e:
            st.error(f"Error loading top products: {e}")
    
    # Revenue by Country Map
    st.markdown("---")
    st.subheader("🌍 Total Revenue by Country")
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT 
                    countryregioncode,
                    SUM(order_total) as total_revenue
                FROM mart_sales
                WHERE countryregioncode IS NOT NULL
                GROUP BY countryregioncode
                ORDER BY total_revenue DESC
            """)
            country_revenue = pd.DataFrame(cur.fetchall(), columns=['Country', 'Revenue'])
            
            if not country_revenue.empty:
                # Convert Revenue to integer to avoid JSON serialization issues with Decimal
                country_revenue['Revenue'] = pd.to_numeric(country_revenue['Revenue'], errors='coerce').fillna(0).astype(int)
                
                # Map ISO-2 country codes to full country names and coordinates
                country_name_map = {
                    'US': 'United States',
                    'CA': 'Canada',
                    'GB': 'United Kingdom',
                    'DE': 'Germany',
                    'FR': 'France',
                    'AU': 'Australia',
                    'NZ': 'New Zealand'
                }
                # Approximate center coordinates for each country
                country_coords = {
                    'US': [39.8283, -98.5795],
                    'CA': [56.1304, -106.3468],
                    'GB': [55.3781, -3.4360],
                    'DE': [51.1657, 10.4515],
                    'FR': [46.2276, 2.2137],
                    'AU': [-25.2744, 133.7751],
                    'NZ': [-40.9006, 174.8860]
                }
                
                # Create a copy for mapping
                country_revenue_map = country_revenue.copy()
                country_revenue_map['Country Name'] = country_revenue_map['Country'].map(country_name_map).fillna(country_revenue_map['Country'])
                country_revenue_map['Lat'] = country_revenue_map['Country'].map(lambda x: country_coords.get(x, [0, 0])[0])
                country_revenue_map['Lon'] = country_revenue_map['Country'].map(lambda x: country_coords.get(x, [0, 0])[1])
                
                # Filter out countries without coordinates
                country_revenue_map = country_revenue_map[(country_revenue_map['Lat'] != 0) | (country_revenue_map['Lon'] != 0)]
                
                if not country_revenue_map.empty:
                    # Create Folium map
                    try:
                        # Create base map centered on world with dark theme
                        m = folium.Map(location=[20, 0], zoom_start=2, tiles='CartoDB dark_matter')
                        
                        # Normalize revenue for color and size
                        max_revenue = int(country_revenue_map['Revenue'].max())
                        min_revenue = int(country_revenue_map['Revenue'].min())
                        revenue_range = max_revenue - min_revenue if max_revenue != min_revenue else 1
                        
                        # Add markers for each country
                        for idx, row in country_revenue_map.iterrows():
                            revenue_val = int(row['Revenue'])
                            
                            # Calculate color intensity for light blue to dark blue gradient
                            # Higher revenue = darker blue, lower revenue = lighter blue
                            intensity = (revenue_val - min_revenue) / revenue_range if revenue_range > 0 else 0
                            
                            # Light blue (low revenue): RGB(173, 216, 230) = #ADD8E6
                            # Dark blue (high revenue): RGB(0, 0, 139) = #00008B
                            red = int(173 - (173 * intensity))
                            green = int(216 - (216 * intensity))
                            blue = int(230 - (91 * intensity))  # 230 to 139
                            color = f'#{red:02x}{green:02x}{blue:02x}'
                            
                            # Calculate marker size based on revenue
                            size = max(10, min(50, 10 + (revenue_val / max_revenue) * 40))
                            
                            # Format revenue with currency and commas
                            revenue_formatted = f"${revenue_val:,}"
                            
                            # Create popup with formatted revenue (dark theme styling)
                            popup_html = f"""
                            <div style="font-family: Arial; font-size: 14px; color: #e0e0e0; background-color: #1e1e1e; padding: 10px; border-radius: 5px;">
                                <b style="color: #ffffff;">{row['Country Name']}</b><br>
                                <span style="color: #87CEEB;">Revenue: {revenue_formatted}</span>
                            </div>
                            """
                            
                            folium.CircleMarker(
                                location=[row['Lat'], row['Lon']],
                                radius=size,
                                popup=folium.Popup(popup_html, max_width=250),
                                tooltip=f"{row['Country Name']}: {revenue_formatted}",
                                color='#ffffff',
                                fillColor=color,
                                fillOpacity=0.8,
                                weight=2
                            ).add_to(m)
                        
                        # Add legend with dark theme styling
                        legend_html = f'''
                        <div style="position: fixed; 
                                    bottom: 50px; right: 50px; width: 220px; height: 140px; 
                                    background-color: #1e1e1e; border:2px solid #4169E1; z-index:9999; 
                                    font-size:14px; padding: 15px; border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.3);">
                        <h4 style="margin-top: 0; color: #ffffff; font-weight: bold;">Revenue Scale</h4>
                        <p style="margin: 8px 0; color: #e0e0e0;"><span style="color: #00008B;">●</span> High: <span style="color: #87CEEB; font-weight: bold;">${max_revenue:,}</span></p>
                        <p style="margin: 8px 0; color: #e0e0e0;"><span style="color: #ADD8E6;">●</span> Low: <span style="color: #87CEEB; font-weight: bold;">${min_revenue:,}</span></p>
                        </div>
                        '''
                        m.get_root().html.add_child(folium.Element(legend_html))
                        
                        # Display map
                        st_folium(m, width=700, height=500)
                    except Exception as e:
                        # Fallback to bar chart if map fails
                        st.warning(f"Map visualization unavailable, showing bar chart instead: {e}")
                        fig = px.bar(country_revenue_map, x='Country Name', y='Revenue',
                                   title='Total Revenue by Country',
                                   labels={'Revenue': 'Revenue ($)', 'Country Name': 'Country'})
                        fig.update_xaxes(tickangle=45)
                        st.plotly_chart(fig, use_container_width=True)
                else:
                    st.info("No country revenue data available for map")
            else:
                st.info("No country revenue data available")
    except Exception as e:
        st.error(f"Error loading country revenue map: {e}")

# Import and route to other pages
elif page == "🤖 AI Assistant":
    from pages import ai_assistant
    ai_assistant.render(conn)
elif page == "💰 Sales & Revenue":
    from pages import sales_revenue
    sales_revenue.render(conn)
elif page == "📦 Product & Inventory":
    from pages import product_inventory
    product_inventory.render(conn)
elif page == "👥 Customer Analytics":
    from pages import customer_analytics
    customer_analytics.render(conn)
elif page == "👔 HR & Employee Performance":
    from pages import hr_analytics
    hr_analytics.render(conn)
elif page == "⚙️ Operations & Supply Chain":
    from pages import operations
    operations.render(conn)
elif page == "🔮 Advanced Analytics":
    from pages import advanced_analytics
    advanced_analytics.render(conn)
elif page == "🛡️ OPAL Authorization Demo":
    from pages import opal_demo
    opal_demo.render(conn)

# Footer
st.markdown("---")
st.caption(f"Last updated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} | AdventureWorks Sample Database")
