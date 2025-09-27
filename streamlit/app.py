from azure.storage.filedatalake import DataLakeServiceClient
import pandas as pd
import streamlit as st
from io import StringIO
from io import BytesIO
import sys
import logging
from azure.identity import DefaultAzureCredential
import gzip

st.set_page_config(layout="wide")

st.title('HKA-Datenplattform')
#st.sidebar.page_link("app.py", label="Startseite")
#st.sidebar.page_link("pages/setup.py", label="Your profile")


def initialize_storage_account():
    try:
        #Installed Azure CLI on the device is a requirement.
        credential = DefaultAzureCredential(exclude_interactive_browser_credential=False)
        service_client = DataLakeServiceClient(account_url='https://hkadpdatalakestorage.dfs.core.windows.net', credential=credential,logging_enable = True)
        
        return service_client
    except Exception as e:
        print(e)
        return None
    
# LIST ALL FILES
def list_files_in_filesystem(file_system_client):
    try:
        paths = file_system_client.get_paths()
        file_list = []
        for path in paths:
            file_list.append(path.name)
        return file_list
    except Exception as e:
        st.error(f"Failed to list paths: {e}")
        return []
    

@st.cache_data
def load_data(_file_system_client):
    directory_client = file_system_client.get_directory_client('hka-aqm')
    file_client = directory_client.get_file_client('data.csv.gz')

    download = file_client.download_file()
    downloaded_bytes = download.readall()

    with gzip.open(BytesIO(downloaded_bytes), mode='rt') as csv_file:
        df = pd.read_csv(csv_file, header=0, sep=';')

    
    df['date_time'] = pd.to_datetime(df['date_time'])
    df['building_number'] = df['device_id'].str.split('-').str[-1].str[0].str.upper()

    return df

@st.cache_data
def load_local_data():
    with gzip.open('./data.csv.gz', mode='rt') as csv_file:
        df = pd.read_csv(csv_file, header=0, sep=';')

    
    df['date_time'] = pd.to_datetime(df['date_time'])
    df['building_number'] = df['device_id'].str.split('-').str[-1].str[0].str.upper()
    
    return df

#MAIN PART
#service_client = initialize_storage_account()
try:
    #file_system_client = service_client.get_file_system_client(file_system='hka-data-platform-datalakecontainer')
    
    # List all files
    #files = list_files_in_filesystem(file_system_client)
    
    #if files:
    #    st.header("Data Lake Storage Index")
    #    for file in files:
    #        st.text(file)
    #else:
    #    st.text("No files found in the container.")
        
    st.divider()
    
    st.header("HKA CO2-Ampeln")
    st.subheader("Filter")
    
    #directory_client = file_system_client.get_directory_client('hka-aqm')
    #file_client = directory_client.get_file_client('data.csv.gz')
    
    #df = load_data(file_system_client)
    
    df = load_local_data()
    
    with st.spinner('Daten werden vorbereitet...'):
            # Filter building
            building_numbers = df['building_number'].unique().tolist()
            building_numbers.insert(0, 'Alle') 
            selected_building = st.selectbox('Gebäude auswählen', building_numbers)

            # Filter device_id
            if selected_building != 'Alle':
                filtered_df = df[df['building_number'] == selected_building]
            else:
                filtered_df = df.copy()

            device_ids = filtered_df['device_id'].unique().tolist()
            device_ids.insert(0, 'Alle')
            selected_device = st.selectbox('Gerät auswählen', device_ids)

            # Filter date range
            min_date = df['date_time'].min().date()
            max_date = df['date_time'].max().date()
            start_date, end_date = st.date_input('Zeitraum auswählen', [min_date, max_date], min_value=min_date, max_value=max_date)

            # Apply filters
            if selected_device != 'Alle':
                filtered_df = filtered_df[filtered_df['device_id'] == selected_device]

            filtered_df = filtered_df[(filtered_df['date_time'].dt.date >= start_date) & (filtered_df['date_time'].dt.date <= end_date)]

            # Display filtered DF
            st.subheader("Übersicht")
            st.write(f"Anzahl der Datensätze: {len(filtered_df.index)}")
            
            st.write(filtered_df.head())
            
            #st.divider()
            st.subheader("Diagramme")
            st.info('Die Daten für die Diagramme verfügen über eine Auflösung von 15 Minuten pro Datenpunkt. Alle Datenpunkte innerhalb der gegebenen Auflösung wurden als Durchschnitt zusammengefasst.', icon="ℹ️")
            sanitize_data = st.checkbox("Messfehler bereinigen",True)
            if sanitize_data:
                st.write('Hinweis: Die Daten werden auf Basis der Standardabweichung bereinigt')
            add_lines = st.checkbox("Maximum, Minimum und Durchschnitt einblenden",True)
            
            if sanitize_data:
                # Define outlier thresholds
                outlier_thresholds = {'CO2': 15, 'hum': 10, 'tmp': 4}

                for col in ['CO2', 'hum', 'tmp']:
                    mean = filtered_df[col].mean()
                    std = filtered_df[col].std()
                    outlier_threshold = outlier_thresholds[col]
                    upper_bound = mean + outlier_threshold * std
                    
                    # Clean up the outliers
                    filtered_df.loc[filtered_df[col] > upper_bound, col] = mean
            
            # Display charts
            if not filtered_df.empty:
                relevant_cols = ['date_time', 'CO2', 'hum', 'tmp']
                grouped_df = filtered_df[relevant_cols].copy()

                # Group data by 15-minute intervals
                grouped_df = grouped_df.groupby(pd.Grouper(key='date_time', freq='15T')).mean().reset_index()
                
                co2 = grouped_df[['date_time','CO2']]
                hum = grouped_df[['date_time','hum']]
                tmp = grouped_df[['date_time','tmp']]
                
                if add_lines:
                    # Calculate average, min, and max for CO2
                    co2['Average'] = grouped_df['CO2'].mean()
                    co2['Min'] = grouped_df['CO2'].min()
                    co2['Max'] = grouped_df['CO2'].max()

                    # Calculate average, min, and max for humidity
                    hum['Average'] = grouped_df['hum'].mean()
                    hum['Min'] = grouped_df['hum'].min()
                    hum['Max'] = grouped_df['hum'].max()

                    # Calculate average, min, and max for temperature
                    tmp['Average'] = grouped_df['tmp'].mean()
                    tmp['Min'] = grouped_df['tmp'].min()
                    tmp['Max'] = grouped_df['tmp'].max()
                
                
                # Write charts
                st.write('CO2')
                st.line_chart(co2.set_index('date_time'), use_container_width=True)
                st.write('Luftfeuchtigkeit')
                st.line_chart(hum.set_index('date_time'), use_container_width=True)
                st.write('Temperatur')
                st.line_chart(tmp.set_index('date_time'), use_container_width=True)
except Exception as e:
    st.error(f"Failed to list paths: {e}")