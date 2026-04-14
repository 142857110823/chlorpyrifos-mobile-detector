
import networkx as nx
import numpy as np


class StructuralResilience:
    def __init__(self, graph):
        self.graph = graph

    def calculate_network_density(self):
        return nx.density(self.graph)

    def calculate_node_centrality_distribution(self):
        degree_centrality = nx.degree_centrality(self.graph)
        betweenness_centrality = nx.betweenness_centrality(self.graph)
        closeness_centrality = nx.closeness_centrality(self.graph)
        return {
            'degree_centrality': degree_centrality,
            'betweenness_centrality': betweenness_centrality,
            'closeness_centrality': closeness_centrality
        }

    def calculate_path_redundancy(self):
        if nx.is_directed(self.graph):
            raise ValueError("Path redundancy calculation is for undirected graphs")
        
        all_pairs_shortest_paths = dict(nx.all_pairs_shortest_path_length(self.graph))
        total_paths = 0
        redundant_paths = 0
        
        for source, targets in all_pairs_shortest_paths.items():
            for target, shortest_length in targets.items():
                if source != target:
                    total_paths += 1
                    all_paths = list(nx.all_simple_paths(self.graph, source, target, cutoff=shortest_length + 1))
                    if len(all_paths) &gt; 1:
                        redundant_paths += 1
        
        return redundant_paths / total_paths if total_paths &gt; 0 else 0

    def calculate_modularity(self, communities=None):
        if communities is None:
            communities = nx.community.greedy_modularity_communities(self.graph)
        return nx.community.modularity(self.graph, communities)

    def get_all_structural_metrics(self):
        centralities = self.calculate_node_centrality_distribution()
        return {
            'network_density': self.calculate_network_density(),
            'avg_degree_centrality': np.mean(list(centralities['degree_centrality'].values())),
            'avg_betweenness_centrality': np.mean(list(centralities['betweenness_centrality'].values())),
            'avg_closeness_centrality': np.mean(list(centralities['closeness_centrality'].values())),
            'path_redundancy': self.calculate_path_redundancy(),
            'modularity': self.calculate_modularity()
        }
