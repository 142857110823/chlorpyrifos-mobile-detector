
import sys
import os

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

import numpy as np
import pandas as pd
from chapter3 import StructuralResilience, OperationalResilience, EnvironmentalResilience
from chapter4 import NodeDeletionSimulation, ResilienceIndexCalculator, CriticalLinkIdentifier
from chapter5 import DataPreparer, ResilienceDiagnostician
from visualization.visualizer import SupplyChainVisualizer


def main():
    print("=" * 80)
    print("跨境电商供应链韧性测度系统")
    print("=" * 80)
    
    np.random.seed(42)
    
    print("\n[步骤1: 准备数据...")
    data_preparer = DataPreparer()
    
    supply_chain_graph = data_preparer.create_sample_supply_chain_graph(
        num_suppliers=5,
        num_manufacturers=3,
        num_distributors=4,
        num_retailers=6
    )
    
    time_series_data = data_preparer.create_sample_time_series_data()
    operational_data = data_preparer.create_sample_operational_data()
    
    print("   ✓ 数据准备完成")
    
    print("\n步骤2: 计算第三章指标体系...")
    structural_resilience = StructuralResilience(supply_chain_graph)
    structural_metrics = structural_resilience.get_all_structural_metrics()
    
    operational_resilience = OperationalResilience(
        order_data=operational_data['order_data'],
        logistics_data=operational_data['logistics_data'],
        procurement_data=operational_data['procurement_data']
    )
    operational_metrics = operational_resilience.get_all_operational_metrics()
    
    environmental_resilience = EnvironmentalResilience()
    environmental_metrics = environmental_resilience.get_all_environmental_metrics()
    
    print("   ✓ 指标体系计算完成")
    
    print("\n步骤3: 第四章 - 结构韧性指标:")
    for key, value in structural_metrics.items():
        print(f"   - {key}: {value:.4f}")
    
    print("\n   运营韧性指标:")
    for key, value in operational_metrics.items():
        print(f"   - {key}: {value:.4f}")
    
    print("\n   环境韧性指标:")
    for key, value in environmental_metrics.items():
        print(f"   - {key}: {value:.4f}")
    
    print("\n步骤4: 计算第四章 - 复杂网络韧性测度...")
    index_calculator = ResilienceIndexCalculator()
    resilience_result = index_calculator.calculate_comprehensive_resilience_index(
        structural_metrics,
        operational_metrics,
        environmental_metrics
    )
    
    node_simulation = NodeDeletionSimulation(supply_chain_graph)
    simulation_result = node_simulation.run_comprehensive_simulation()
    
    critical_identifier = CriticalLinkIdentifier(supply_chain_graph)
    network_diagnosis = critical_identifier.get_network_diagnosis()
    
    print("   ✓ 韧性测度完成")
    
    print("\n步骤5: 韧性测度结果:")
    print(f"   综合韧性指数: {resilience_result['comprehensive_index']:.4f}")
    print(f"   结构韧性指数: {resilience_result['structural_index']:.4f}")
    print(f"   运营韧性指数: {resilience_result['operational_index']:.4f}")
    print(f"   环境韧性指数: {resilience_result['environmental_index']:.4f}")
    
    print("\n步骤6: 第五章 - 诊断分析...")
    diagnostician = ResilienceDiagnostician()
    diagnosis_report = diagnostician.generate_diagnosis_report(
        resilience_result,
        structural_metrics,
        operational_metrics,
        environmental_metrics,
        network_diagnosis
    )
    print("   ✓ 诊断分析完成")
    
    print("\n" + "=" * 80)
    print("诊断报告摘要")
    print("=" * 80)
    print(f"\n整体评估: {diagnosis_report['overall_assessment']['level']}")
    print(f"得分: {diagnosis_report['overall_assessment']['score']:.4f}")
    print(f"描述: {diagnosis_report['overall_assessment']['description']}")
    
    print(f"\n最弱维度: {diagnosis_report['dimension_analysis']['weakest_dimension']}")
    print(f"最强维度: {diagnosis_report['dimension_analysis']['strongest_dimension']}")
    
    print("\n关键节点:")
    for node, score in diagnosis_report['network_critical_nodes'][:3]:
        print(f"   - {node}: {score:.4f}")
    
    print("\n优化建议:")
    for i, rec in enumerate(diagnosis_report['recommendations'], 1):
        print(f"   {i}. {rec}")
    
    print("\n" + "=" * 80)
    print("生成可视化...")
    visualizer = SupplyChainVisualizer()
    
    try:
        visualizer.plot_supply_chain_network(supply_chain_graph)
        print("   ✓ 网络可视化生成")
    except Exception as e:
        print(f"   网络可视化跳过")
    
    try:
        visualizer.plot_resilience_dimensions(resilience_result)
        print("   ✓ 维度得分可视化生成")
    except Exception as e:
        print(f"   维度可视化跳过")
    
    try:
        if diagnosis_report.get('network_critical_nodes'):
            visualizer.plot_critical_nodes(diagnosis_report['network_critical_nodes'])
            print("   ✓ 关键节点可视化生成")
    except Exception as e:
        print(f"   关键节点可视化跳过")
    
    try:
        visualizer.plot_comprehensive_report(diagnosis_report)
        print("   ✓ 综合报告可视化生成")
    except Exception as e:
        print(f"   综合报告可视化跳过")
    
    print("\n" + "=" * 80)
    print("所有步骤完成！")
    print("=" * 80)


if __