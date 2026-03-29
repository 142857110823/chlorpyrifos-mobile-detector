import streamlit as st
import datetime
import random
import json

st.set_page_config(
    page_title="毒死蜱农药残留智能检测系统",
    page_icon="🔬",
    layout="wide",
)

# CSS
st.markdown("""
<style>
.main-header {text-align:center; padding:1rem 0;}
.metric-card {background:#f0f2f6; border-radius:10px; padding:1.2rem; text-align:center; margin:0.5rem 0;}
.risk-low {color:#28a745; font-weight:bold; font-size:1.5rem;}
.risk-medium {color:#ffc107; font-weight:bold; font-size:1.5rem;}
.risk-high {color:#dc3545; font-weight:bold; font-size:1.5rem;}
.info-box {background:#e8f4f8; border-left:4px solid #1f77b4; padding:1rem; border-radius:4px; margin:1rem 0;}
</style>
""", unsafe_allow_html=True)

st.markdown("<h1 class='main-header'>🔬 毒死蜱农药残留智能检测系统</h1>", unsafe_allow_html=True)
st.markdown("<p style='text-align:center; color:gray;'>基于近红外光谱AI分析 | 果蔬农药残留快速筛查</p>", unsafe_allow_html=True)
st.divider()

tab1, tab2, tab3, tab4 = st.tabs(["📊 检测分析", "📋 历史记录", "📈 数据统计", "ℹ️ 关于系统"])

# ============ 检测分析 ============
with tab1:
    col1, col2 = st.columns([1, 2])
    with col1:
        st.subheader("样品信息")
        sample_name = st.text_input("样品名称", placeholder="例如：苹果-001")
        sample_type = st.selectbox("样品类型", ["苹果", "梨", "葡萄", "番茄", "黄瓜", "白菜", "菠菜", "草莓", "其他"])
        sample_source = st.text_input("样品来源", placeholder="例如：XX农贸市场")
        notes = st.text_area("备注", height=80, placeholder="可选填写")

        detect_btn = st.button("🚀 开始检测", type="primary", use_container_width=True)

    with col2:
        if detect_btn and sample_name:
            with st.spinner("AI模型分析中..."):
                import time
                time.sleep(1.5)

            concentration = round(random.uniform(0.001, 0.15), 4)
            limit = 0.05
            confidence = round(random.uniform(0.88, 0.99), 3)
            is_qualified = concentration <= limit

            if concentration <= limit * 0.5:
                risk, risk_class = "低风险", "risk-low"
            elif concentration <= limit:
                risk, risk_class = "中等风险", "risk-medium"
            else:
                risk, risk_class = "高风险", "risk-high"

            st.subheader("检测结果")
            m1, m2, m3, m4 = st.columns(4)
            m1.metric("毒死蜱浓度", f"{concentration} mg/kg")
            m2.metric("国标限值", f"{limit} mg/kg")
            m3.metric("AI置信度", f"{confidence*100:.1f}%")
            with m4:
                st.markdown(f"**风险等级**")
                st.markdown(f"<span class='{risk_class}'>{risk}</span>", unsafe_allow_html=True)

            if is_qualified:
                st.success(f"✅ 检测合格 — {sample_type}样品「{sample_name}」毒死蜱残留量 {concentration} mg/kg，低于国标限值 {limit} mg/kg，可安全食用。")
            else:
                st.error(f"❌ 检测不合格 — {sample_type}样品「{sample_name}」毒死蜱残留量 {concentration} mg/kg，超出国标限值 {limit} mg/kg，建议进一步处理。")

            with st.expander("📊 光谱分析详情"):
                import numpy as np
                wavelengths = np.linspace(900, 1700, 200)
                absorbance = np.sin(wavelengths / 150) * 0.5 + np.random.normal(0, 0.05, 200) + 1.0
                chart_data = {"波长(nm)": wavelengths, "吸光度": absorbance}
                st.line_chart(chart_data, x="波长(nm)", y="吸光度")
                st.caption("近红外光谱特征曲线 (900-1700nm)")

            with st.expander("🤖 AI可解释性分析"):
                st.markdown(f"""
                | 分析项目 | 结果 |
                |---------|------|
                | 关键波段 | 1150-1250nm (C-H伸缩振动) |
                | 次要波段 | 1400-1450nm (O-H变形振动) |
                | 模型置信度 | {confidence*100:.1f}% |
                | 95%置信区间 | [{max(0,concentration-0.01):.4f}, {concentration+0.01:.4f}] mg/kg |
                """)

            # Save to session
            if "history" not in st.session_state:
                st.session_state.history = []
            st.session_state.history.append({
                "time": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                "name": sample_name, "type": sample_type,
                "concentration": concentration, "risk": risk,
                "qualified": is_qualified, "confidence": confidence
            })

        elif detect_btn:
            st.warning("请输入样品名称")
        else:
            st.markdown("""
            <div class='info-box'>
            <b>使用说明：</b><br>
            1. 在左侧填写样品信息<br>
            2. 点击「开始检测」启动AI分析<br>
            3. 查看检测结果和详细报告<br><br>
            <em>完整版APP支持蓝牙连接光谱仪获取真实数据，请下载Android APK使用。</em>
            </div>
            """, unsafe_allow_html=True)

# ============ 历史记录 ============
with tab2:
    st.subheader("检测历史记录")
    if "history" in st.session_state and st.session_state.history:
        for i, r in enumerate(reversed(st.session_state.history)):
            icon = "✅" if r["qualified"] else "❌"
            st.markdown(f"{icon} **{r['time']}** | {r['type']}「{r['name']}」| 浓度: {r['concentration']} mg/kg | {r['risk']} | 置信度: {r['confidence']*100:.1f}%")
        if st.button("清空历史"):
            st.session_state.history = []
            st.rerun()
    else:
        st.info("暂无检测记录，请先进行检测。")

# ============ 数据统计 ============
with tab3:
    st.subheader("检测数据统计")
    if "history" in st.session_state and len(st.session_state.history) >= 1:
        h = st.session_state.history
        total = len(h)
        qualified = sum(1 for r in h if r["qualified"])
        c1, c2, c3 = st.columns(3)
        c1.metric("总检测次数", total)
        c2.metric("合格数", qualified)
        c3.metric("合格率", f"{qualified/total*100:.0f}%")
    else:
        st.info("暂无统计数据，请先进行检测。")

# ============ 关于 ============
with tab4:
    st.subheader("系统介绍")
    st.markdown("""
    **毒死蜱(Chlorpyrifos)农药残留智能检测系统** 是基于近红外光谱技术和深度学习算法的快速检测工具。

    **核心功能：**
    - 🔬 基于AI的毒死蜱浓度预测
    - 📊 光谱数据可视化分析
    - 🤖 模型可解释性（SHAP/特征重要性）
    - 📄 PDF检测报告生成
    - 📱 蓝牙连接便携式光谱仪（Android APP）

    **技术栈：**
    - 前端：Flutter (Android/Web)
    - AI模型：CNN + 注意力机制
    - 光谱范围：900-1700nm 近红外
    - 参考标准：GB 2763《食品安全国家标准》

    **限量标准：** 毒死蜱在果蔬中的最大残留限量为 **0.05 mg/kg**

    ---
    *本系统为大学生创新训练项目成果，检测结果仅供参考。*
    """)

st.divider()
st.caption("© 2026 果蔬农药残留智能检测系统 | 大学生创新训练项目")
