
import numpy as np


class EnvironmentalResilience:
    def __init__(self, policy_data=None, infrastructure_data=None, financial_data=None, emergency_data=None):
        self.policy_data = policy_data
        self.infrastructure_data = infrastructure_data
        self.financial_data = financial_data
        self.emergency_data = emergency_data

    def calculate_policy_stability(self):
        if self.policy_data is None:
            return 0.7
        return np.mean(self.policy_data['stability_score'])

    def calculate_digital_infrastructure_level(self):
        if self.infrastructure_data is None:
            return 0.85
        metrics = [
            self.infrastructure_data['internet_penetration'],
            self.infrastructure_data['5g_coverage'],
            self.infrastructure_data['logistics_digitalization']
        ]
        return np.mean(metrics)

    def calculate_financial_service_accessibility(self):
        if self.financial_data is None:
            return 0.75
        metrics = [
            self.financial_data['loan_approval_rate'],
            self.financial_data['insurance_coverage'],
            self.financial_data['payment_system_reliability']
        ]
        return np.mean(metrics)

    def calculate_social_emergency_coordination(self):
        if self.emergency_data is None:
            return 0.65
        return np.mean(self.emergency_data['coordination_score'])

    def get_all_environmental_metrics(self):
        return {
            'policy_stability': self.calculate_policy_stability(),
            'digital_infrastructure_level': self.calculate_digital_infrastructure_level(),
            'financial_service_accessibility': self.calculate_financial_service_accessibility(),
            'social_emergency_coordination': self.calculate_social_emergency_coordination()
        }
