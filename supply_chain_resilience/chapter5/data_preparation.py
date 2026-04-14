
import pandas as pd
import numpy as np
import networkx as nx
from typing import Dict, List, Optional


class DataPreparer:
    def __init__(self):
        pass

    def create_sample_supply_chain_graph(
        self,
        num_suppliers: int = 5,
        num_manufacturers: int = 3,
        num_distributors: int = 4,
        num_retailers: int = 6
    ) -&gt; nx.Graph:
        G = nx.Graph()
        
        suppliers = [f'S{i+1}' for i in range(num_suppliers)]
        manufacturers = [f'M{i+1}' for i in range(num_manufacturers)]
        distributors = [f'D{i+1}' for i in range(num_distributors)]
        retailers = [f'R{i+1}' for i in range(num_retailers)]
        
        all_nodes = suppliers + manufacturers + distributors + retailers
        G.add_nodes_from(all_nodes)
        
        for supplier in suppliers:
            num_connections = np.random.randint(1, min(3, num_manufacturers) + 1)
            connected_manufacturers = np.random.choice(manufacturers, num_connections, replace=False)
            for manufacturer in connected_manufacturers:
                weight = np.random.uniform(0.5, 1.0)
                G.add_edge(supplier, manufacturer, weight=weight)
        
        for manufacturer in manufacturers:
            num_connections = np.random.randint(2, min(4, num_distributors) + 1)
            connected_distributors = np.random.choice(distributors, num_connections, replace=False)
            for distributor in connected_distributors:
                weight = np.random.uniform(0.6, 1.0)
                G.add_edge(manufacturer, distributor, weight=weight)
        
        for distributor in distributors:
            num_connections = np.random.randint(2, min(5, num_retailers) + 1)
            connected_retailers = np.random.choice(retailers, num_connections, replace=False)
            for retailer in connected_retailers:
                weight = np.random.uniform(0.7, 1.0)
                G.add_edge(distributor, retailer, weight=weight)
        
        for i, node in enumerate(all_nodes):
            if node.startswith('S'):
                G.nodes[node]['type'] = 'supplier'
                G.nodes[node]['capacity'] = np.random.randint(1000, 5000)
            elif node.startswith('M'):
                G.nodes[node]['type'] = 'manufacturer'
                G.nodes[node]['capacity'] = np.random.randint(2000, 8000)
            elif node.startswith('D'):
                G.nodes[node]['type'] = 'distributor'
                G.nodes[node]['capacity'] = np.random.randint(1500, 6000)
            else:
                G.nodes[node]['type'] = 'retailer'
                G.nodes[node]['capacity'] = np.random.randint(500, 2000)
        
        return G

    def create_sample_time_series_data(
        self,
        years: List[int] = list(range(2007, 2023))
    ) -&gt; pd.DataFrame:
        data = {
            'year': years,
            'cross_border_transaction_volume': np.random.randint(10000, 50000, size=len(years)) * (1 + np.linspace(0, 0.8, len(years))),
            'num_enterprises': np.random.randint(500, 2000, size=len(years)) * (1 + np.linspace(0, 0.5, len(years))),
            'logistics_employment': np.random.randint(10000, 50000, size=len(years)) * (1 + np.linspace(0, 0.3, len(years))),
            'logistics_investment': np.random.randint(100, 500, size=len(years)) * (1 + np.linspace(0, 0.6, len(years))),
            'total_social_logistics': np.random.randint(5000, 20000, size=len(years)) * (1 + np.linspace(0, 0.4, len(years))),
            'express_volume': np.random.randint(10000, 100000, size=len(years)) * (1 + np.linspace(0, 1.2, len(years))),
            'export_concentration': np.random.uniform(0.3, 0.7, size=len(years))
        }
        return pd.DataFrame(data)

    def create_sample_operational_data(self) -&gt; Dict:
        return {
            'order_data': pd.DataFrame({
                'baseline_fulfillment_rate': np.random.uniform(0.85, 0.95, 100),
                'peak_fulfillment_rate': np.random.uniform(0.7, 0.9, 100)
            }),
            'logistics_data': pd.DataFrame({
                'delivery_time_days': np.random.normal(5, 1.5, 200)
            }),
            'procurement_data': pd.DataFrame({
                'num_suppliers': np.random.randint(1, 5, 50),
                'data_shared': np.random.choice([True, False], 50, p=[0.7, 0.3])
            })
        }

    def fill_missing_data(self, df: pd.DataFrame, method: str = 'interpolate') -&gt; pd.DataFrame:
        df_filled = df.copy()
        
        for column in df_filled.columns:
            if df_filled[column].dtype in [np.float64, np.int64]:
                if method == 'mean':
                    df_filled[column] = df_filled[column].fillna(df_filled[column].mean())
                elif method == 'interpolate':
                    df_filled[column] = df_filled[column].interpolate()
                elif method == 'forward':
                    df_filled[column] = df_filled[column].fillna(method='ffill')
        
        return df_filled
