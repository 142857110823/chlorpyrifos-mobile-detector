
import numpy as np
import pandas as pd
import networkx as nx
from typing import Dict, List, Tuple


class ResilienceDiagnostician:
    def __init__(self):
        pass

    def assess_overall_resilience_level(self, comprehensive_index: float) -&gt; Dict:
        if comprehensive_index &gt;= 0.8:
            level = "High"
            description = "供应链具有很强的韧性，能够有效抵御各类风险冲击"
        elif comprehensive_index &gt;= 0.6:
            level = "Medium-High"
            description = "供应链韧性较好，但仍有提升空间"
        elif comprehensive_index &gt;= 0.4:
            level = "Medium"
            description = "供应链韧性一般，需要关注关键环节"
        elif comprehensive_index &gt;= 0.2:
            level = "Medium-Low"
            description = "供应链韧性较弱，存在较多脆弱点"
        else:
            level = "Low"
            description = "供应链韧性很差，急需系统性优化"
        
        return {
            'level': level,
            'score': comprehensive_index,
            'description': description
        }

    def analyze_dimension_contribution(self, resilience_result: Dict) -&gt; Dict:
        structural = resilience_result['structural_index']
        operational = resilience_result['operational_index']
        environmental = resilience_result['environmental_index']
        
        dimensions = [
            ('structural', structural),
            ('operational', operational),
            ('environmental', environmental)
        ]
        
        sorted_dimensions = sorted(dimensions, key=lambda x: x[1])
        weakest_dimension = sorted_dimensions[0][0]
        strongest_dimension = sorted_dimensions[-1][0]
        
        return {
            'dimension_scores': {
                'structural': structural,
                'operational': operational,
                'environmental': environmental
            },
            'weakest_dimension': weakest_dimension,
            'strongest_dimension': strongest_dimension,
            'improvement_priority': [d[0] for d in sorted_dimensions]
        }

    def identify_weaknesses_from_metrics(
        self,
        structural_metrics: Dict,
        operational_metrics: Dict,
        environmental_metrics: Dict,
        threshold: float = 0.5
    ) -&gt; List[Dict]:
        weaknesses = []
        
        all_metrics = {
            'structural': structural_metrics,
            'operational': operational_metrics,
            'environmental': environmental_metrics
        }
        
        for dimension, metrics in all_metrics.items():
            for metric_name, value in metrics.items():
                if value &lt; threshold:
                    weaknesses.append({
                        'dimension': dimension,
                        'metric': metric_name,
                        'value': value,
                        'threshold': threshold,
                        'gap': threshold - value
                    })
        
        return sorted(weaknesses, key=lambda x: x['gap'], reverse=True)

    def generate_diagnosis_report(
        self,
        resilience_result: Dict,
        structural_metrics: Dict,
        operational_metrics: Dict,
        environmental_metrics: Dict,
        network_diagnosis: Dict = None
    ) -&gt; Dict:
        overall_assessment = self.assess_overall_resilience_level(resilience_result['comprehensive_index'])
        dimension_analysis = self.analyze_dimension_contribution(resilience_result)
        weaknesses = self.identify_weaknesses_from_metrics(
            structural_metrics, operational_metrics, environmental_metrics
        )
        
        report = {
            'overall_assessment': overall_assessment,
            'dimension_analysis': dimension_analysis,
            'key_weaknesses': weaknesses[:10],
            'recommendations': []
        }
        
        weakest_dim = dimension_analysis['weakest_dimension']
        if weakest_dim == 'structural':
            report['recommendations'].append(
                "优先优化网络结构：增加路径冗余，培育备份枢纽节点"
            )
        elif weakest_dim == 'operational':
            report['recommendations'].append(
                "优先优化运营流程：推行弹性库存策略，发展多源采购"
            )
        else:
            report['recommendations'].append(
                "优先优化环境支撑：推动数据标准互认，构建应急协同机制"
            )
        
        if network_diagnosis:
            report['network_critical_nodes'] = network_diagnosis.get('critical_nodes', [])
            report['network_vulnerable_links'] = network_diagnosis.get('vulnerable_links', [])
            if network_diagnosis.get('critical_nodes'):
                report['recommendations'].append(
                    f"重点保护关键节点：{[node[0] for node in network_diagnosis['critical_nodes'][:3]]}"
                )
        
        return report
