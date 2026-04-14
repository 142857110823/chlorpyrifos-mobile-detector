
import numpy as np
import networkx as nx
from sklearn.preprocessing import MinMaxScaler


class ResilienceIndexCalculator:
    def __init__(self):
        self.scaler = MinMaxScaler()

    def normalize_metrics(self, metrics_dict):
        keys = list(metrics_dict.keys())
        values = np.array(list(metrics_dict.values())).reshape(-1, 1)
        
        if len(values) &gt; 1:
            normalized_values = self.scaler.fit_transform(values).flatten()
        else:
            normalized_values = np.array([1.0])
        
        return dict(zip(keys, normalized_values))

    def calculate_weighted_index(self, metrics_dict, weights_dict):
        normalized_metrics = self.normalize_metrics(metrics_dict)
        index_value = 0
        
        for key, value in normalized_metrics.items():
            weight = weights_dict.get(key, 1.0 / len(normalized_metrics))
            index_value += value * weight
        
        return index_value

    def calculate_comprehensive_resilience_index(
        self, 
        structural_metrics, 
        operational_metrics, 
        environmental_metrics,
        dimension_weights=None
    ):
        if dimension_weights is None:
            dimension_weights = {
                'structural': 0.4,
                'operational': 0.35,
                'environmental': 0.25
            }
        
        structural_index = self.calculate_weighted_index(
            structural_metrics, 
            {k: 1/len(structural_metrics) for k in structural_metrics}
        )
        
        operational_index = self.calculate_weighted_index(
            operational_metrics, 
            {k: 1/len(operational_metrics) for k in operational_metrics}
        )
        
        environmental_index = self.calculate_weighted_index(
            environmental_metrics, 
            {k: 1/len(environmental_metrics) for k in environmental_metrics}
        )
        
        comprehensive_index = (
            structural_index * dimension_weights['structural'] +
            operational_index * dimension_weights['operational'] +
            environmental_index * dimension_weights['environmental']
        )
        
        return {
            'comprehensive_index': comprehensive_index,
            'structural_index': structural_index,
            'operational_index': operational_index,
            'environmental_index': environmental_index,
            'dimension_weights': dimension_weights
        }


class CriticalLinkIdentifier:
    def __init__(self, graph):
        self.graph = graph

    def identify_critical_nodes(self, top_n=5):
        betweenness = nx.betweenness_centrality(self.graph)
        degree = nx.degree_centrality(self.graph)
        closeness = nx.closeness_centrality(self.graph)
        
        combined_scores = {}
        for node in self.graph.nodes:
            combined_scores[node] = (
                betweenness[node] * 0.5 +
                degree[node] * 0.3 +
                closeness[node] * 0.2
            )
        
        sorted_nodes = sorted(combined_scores.items(), key=lambda x: x[1], reverse=True)
        return sorted_nodes[:top_n]

    def identify_vulnerable_links(self, top_n=5):
        edge_betweenness = nx.edge_betweenness_centrality(self.graph)
        sorted_edges = sorted(edge_betweenness.items(), key=lambda x: x[1], reverse=True)
        return sorted_edges[:top_n]

    def detect_communities(self):
        try:
            communities = nx.community.greedy_modularity_communities(self.graph)
            return list(communities)
        except:
            return []

    def get_network_diagnosis(self):
        critical_nodes = self.identify_critical_nodes()
        vulnerable_links = self.identify_vulnerable_links()
        communities = self.detect_communities()
        
        return {
            'critical_nodes': critical_nodes,
            'vulnerable_links': vulnerable_links,
            'communities': communities,
            'num_communities': len(communities)
        }
