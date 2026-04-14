
import networkx as nx
import numpy as np
from copy import deepcopy


class NodeDeletionSimulation:
    def __init__(self, base_graph, order_fulfillment_func=None):
        self.base_graph = base_graph
        self.order_fulfillment_func = order_fulfillment_func or self._default_order_fulfillment

    def _default_order_fulfillment(self, graph):
        if len(graph.nodes) == 0:
            return 0
        avg_degree = np.mean([d for n, d in graph.degree()])
        max_possible_degree = len(graph.nodes) - 1 if len(graph.nodes) &gt; 1 else 1
        return avg_degree / max_possible_degree if max_possible_degree &gt; 0 else 0

    def calculate_benchmark_performance(self):
        return self.order_fulfillment_func(self.base_graph)

    def simulate_node_weakening(self, node, weakening_factor=0.5):
        weakened_graph = deepcopy(self.base_graph)
        
        if node in weakened_graph.nodes:
            neighbors = list(weakened_graph.neighbors(node))
            for neighbor in neighbors:
                if weakened_graph.has_edge(node, neighbor):
                    if 'weight' in weakened_graph[node][neighbor]:
                        weakened_graph[node][neighbor]['weight'] *= weakening_factor
                    else:
                        weakened_graph[node][neighbor]['weight'] = weakening_factor
        
        return weakened_graph

    def simulate_node_removal(self, node):
        modified_graph = deepcopy(self.base_graph)
        if node in modified_graph.nodes:
            modified_graph.remove_node(node)
        return modified_graph

    def calculate_performance_drop(self, modified_graph, benchmark_performance):
        current_performance = self.order_fulfillment_func(modified_graph)
        drop = benchmark_performance - current_performance
        return max(drop, 0)

    def calculate_contribution_weights(self, nodes=None):
        if nodes is None:
            nodes = list(self.base_graph.nodes)
        
        benchmark = self.calculate_benchmark_performance()
        drops = {}
        
        for node in nodes:
            modified_graph = self.simulate_node_removal(node)
            drop = self.calculate_performance_drop(modified_graph, benchmark)
            drops[node] = drop
        
        total_drop = sum(drops.values())
        if total_drop == 0:
            weights = {node: 1.0 / len(nodes) for node in nodes}
        else:
            weights = {node: drop / total_drop for node, drop in drops.items()}
        
        return weights, drops

    def run_comprehensive_simulation(self):
        benchmark = self.calculate_benchmark_performance()
        weights, drops = self.calculate_contribution_weights()
        
        return {
            'benchmark_performance': benchmark,
            'node_weights': weights,
            'performance_drops': drops,
            'total_drop': sum(drops.values())
        }
