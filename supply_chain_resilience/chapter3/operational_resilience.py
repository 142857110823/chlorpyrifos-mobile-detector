
import numpy as np


class OperationalResilience:
    def __init__(self, order_data=None, logistics_data=None, procurement_data=None):
        self.order_data = order_data
        self.logistics_data = logistics_data
        self.procurement_data = procurement_data

    def calculate_order_fulfillment_elasticity(self):
        if self.order_data is None:
            return 0.75
        baseline_fulfillment = np.mean(self.order_data['baseline_fulfillment_rate'])
        peak_fulfillment = np.mean(self.order_data['peak_fulfillment_rate'])
        return peak_fulfillment / baseline_fulfillment if baseline_fulfillment &gt; 0 else 0

    def calculate_logistics_timing_volatility(self):
        if self.logistics_data is None:
            return 0.15
        delivery_times = self.logistics_data['delivery_time_days']
        mean_time = np.mean(delivery_times)
        std_time = np.std(delivery_times)
        volatility = std_time / mean_time if mean_time &gt; 0 else 0
        return 1 - volatility

    def calculate_multi_source_procurement_ratio(self):
        if self.procurement_data is None:
            return 0.6
        total_suppliers = len(self.procurement_data)
        multi_source_items = len(self.procurement_data[self.procurement_data['num_suppliers'] &gt;= 2])
        return multi_source_items / total_suppliers if total_suppliers &gt; 0 else 0

    def calculate_data_sharing_level(self):
        if self.procurement_data is None:
            return 0.8
        shared_data_count = len(self.procurement_data[self.procurement_data['data_shared'] == True])
        total_count = len(self.procurement_data)
        return shared_data_count / total_count if total_count &gt; 0 else 0

    def get_all_operational_metrics(self):
        return {
            'order_fulfillment_elasticity': self.calculate_order_fulfillment_elasticity(),
            'logistics_timing_volatility': self.calculate_logistics_timing_volatility(),
            'multi_source_procurement_ratio': self.calculate_multi_source_procurement_ratio(),
            'data_sharing_level': self.calculate_data_sharing_level()
        }
