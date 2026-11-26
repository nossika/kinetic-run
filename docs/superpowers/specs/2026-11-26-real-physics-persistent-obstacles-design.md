# 《给我滚》全实体真实刚体物理碰撞、形状力学调优与赛道留存设计文档

- **日期**：2026-11-26
- **前置架构**：
  - `docs/superpowers/specs/2026-11-25-gravity-tilt-roguelike-design.md`
  - `docs/superpowers/specs/2026-11-25-tabletop-visual-physics-verticality-design.md`
- **引擎与物理后端**：Godot 4.6（`gl_compatibility` 渲染器，**Jolt Physics 3D**，兼容桌面端原生与 Web HTML5 导出）
- **核心设计目标**：
  1. **告别“假传感器撞飞消失”，实现 100% 原生牛顿刚体碰撞**：移除所有活动障碍物外层的提前拦截 `Area3D`、固定抛物线速度覆盖、关闭地形碰撞（`collision_mask = 0`）以及 `0.75s` 定时销毁逻辑；所有活动障碍物从出生起即为真实 `RigidBody3D`，由 Jolt 物理引擎根据**真实质量比、三维几何形状、接触点位置与材质弹性/摩擦**原生求解线速度与角动量。
  2. **全程留存赛道，释放物理连锁涌现感**：被撞飞、推翻或气浪掀动的积木、球瓶、果冻、砝码、坠落气球/磁浮铁及炸后空铁皮桶**永久保留在本关跑道上**（仅跌出跑道坠入 `local_y < -28.0m` 深渊时静默回收），支持顺坡翻滚、撞护栏反弹、推倒其他积木、多米诺倾覆以及滚撞引爆远处爆竹铁皮桶。
  3. **修正物理直觉失衡并补齐“高重心倾覆”形状维度**：将反直觉的 `2kg` 漂浮气球修正为 `250g` 超高弹充气球；将重木箱调整为 `2.0kg` 黄金成长阈值并赋予斜向摆放角（移出无护栏窄桥）；去除铁皮桶与固定弹球柱的隔空触发圈；新增 **`800g` 榉木高球瓶（`WoodenPin`）** 展现抄底空翻与倒地顺坡滚扫的形状力学魅力。
  4. **接触冲量无缝桥接肉鸽词条构筑**：在不人工篡改基础物理球速的前提下，基于 `PlayerBall3D._integrate_forces` 捕获的真实接触冲量与法向反弹速度驱动「实心钨核」「动能殉爆炉」「碎障续秒器」「矢量折射核心」「动量过载」等全部 12 张词条。

---

## 1. 核心物理规则与通用刚体生命周期

### 1.1 纯正牛顿质量比与三维接触几何结算
- **零预设抛射、零球速硬覆写**：
  - 主角球（初始 `mass = 1.5 kg`，半径 `0.55 m`）与任何活动障碍物的碰撞完全交由 Jolt Physics 3D 刚体求解器处理。
  - **质量比真实生效**：`1.5kg` 钨钢球撞 `250g` 气球、`500g` 轻木块、`800g` 高木瓶时占据明显动量优势，顺畅顶飞对方；正撞 `2.0kg` 包角重木箱或 `3.0kg` 果冻怪时球会自然减速或弹偏；正撞 `12kg` 磁浮铁块或 `20kg` 铸铁大砝码时，无论未强化球速多快都会被实打实弹回，而重砝码仅沉重微移几厘米——迫使玩家运用**斜擦棱角、跳台飞跃、引爆铁桶气浪或叠高质量词条（如「实心钨核」「巨球力场」）**破局。
  - **接触形状与力矩真实生效**：正撞平面传递最大法向冲量；斜擦方箱棱角产生强烈偏心力矩 $\boldsymbol{\tau} = (\mathbf{r}_c - \mathbf{r}_{\text{com}}) \times \mathbf{J}$，使木箱高速自旋让路而小球仅轻微偏转；撞击细高球瓶下半截（低于质心）触发抄底空翻力矩。

### 1.2 `11°` 坡面稳驻与撞后自然翻滚（双态阻尼机制）
赛道根节点 `GeneratedTrack` 恒定保持绕 `+X` 轴 `-11.0°` 倾斜（坡面自滑摩擦临界值 $\tan 11^\circ \approx 0.1944$），全局空间重力恒定为 `Vector3(0.0, -22.0, 0.0)`：
1. **受撞前（静止驻坡态）**：
   - 跑道榉木地板配置 `friction = 0.88, bounce = 0.12`；所有平底搁置刚体配置表面摩擦 `friction = 0.68 ~ 0.88`（合成摩擦系数远大于 `0.1944`），配合初始驻坡线性阻尼 `linear_damp = 1.2`、角阻尼 `angular_damp = 1.8`，确保未受外力波及时 `500g` ~ `20kg` 全部物体稳驻 `11°` 坡面绝不自行溜坡，静止后自然进入 Jolt 物理休眠（Sleep）。
2. **受撞后（自由物理留存态 `is_dislodged = true`）**：
   - 一旦刚体承受真实碰撞或爆炸冲击波脱离初始稳态，立即切换至真实空气阻尼（地面硬物 `linear_damp = 0.10 ~ 0.18, angular_damp = 0.18 ~ 0.32`），**保留 `collision_layer = 1` 与 `collision_mask = 1`**。
   - 物体在跑道木板、磨砂亚克力护栏、固定缓冲柱与其他障碍物之间自由弹跳、翻滚、滑行，最终依靠木板表面真实摩擦力自然停稳在跑道某处，持续作为赛场真实物理环境的一部分直至本关结束。
3. **深渊坠落边界清理**：
   - 彻底废除定时 `queue_free()`。仅当活动刚体翻出无护栏窄桥或断桥缺口，在赛道局部坐标系下跌落至 `local_pos.y < -28.0 m`（远低于相机视野与主角球 `-8.0 m` 拉回线）时执行静默销毁，避免深渊无限下坠。

---

## 2. 全实体物理参数、形状力学与状态规范

### 2.1 可动实体阵容总表（7 类规格）

| 实体名称与类名 | 碰撞几何形状 | 表面印字 | 真实质量 `mass` | 物理材质 (`friction` / `bounce`) | 受撞前行为 | 受撞 / 气浪波及后的留存表现 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **轻木小积木**<br>`CrateObstacle` (`light`) | `BoxShape3D`<br>`0.96 × 0.96 × 0.96 m` | **`500g`** | **`0.50 kg`** | `0.72` / `0.24` | 静置坡面，带种子决定的 `±25°` 随机偏转摆放角 | 被 `1.5kg` 球轻松顶飞并剧烈打转，撞击护栏或推倒前方球瓶/积木后停留在木轨上。 |
| **榉木高球瓶（新增）**<br>`WoodenPin` | `CylinderShape3D`<br>`R = 0.28 m, H = 1.56 m`<br>（质心微沉至 `-0.10 m`） | **`800g`** | **`0.80 kg`** | `0.74` / `0.28` | 平底稳立于 `11°` 坡面（重心投影远在底圆内，绝不自倒） | 球心（`0.55m`）撞击质心下方触发凌空后空翻；倒地横躺后圆柱侧面顺 `11°` 木坡滚动扫荡周围路障！ |
| **爆竹铁皮桶**<br>`ExplosiveBarrel` | `CylinderShape3D`<br>`R = 0.52 m, H = 1.25 m` | 引爆前 **`1.5kg`**<br>炸后 **`EMPTY`** | 引爆前 **`1.50 kg`**<br>炸后 **`0.45 kg`** | `0.72` / `0.28` | 静置坡面，**无外扩空气传感器**，仅桶身真实接触触发 | 主角球触碰或其他刚体相对撞击速率 `> 2.6 m/s` 引爆：释放 `6.5m` 物理气浪；自身切换焦黑烟熏铁皮材质、减重至 `0.45kg` 空桶壳飞出翻滚留存，不再二次爆炸。 |
| **包角重积木**<br>`CrateObstacle` (`medium`) | `BoxShape3D`<br>`1.20 × 1.20 × 1.20 m` | **`2kg`** | **`2.00 kg`** | `0.78` / `0.16` | 静置坡面，带 `18° ~ 42°` 斜角摆放（不在无护栏窄桥生成） | 略重于初始 `1.5kg` 球：正撞会令未强化球明显减速并沉重推开箱体；斜擦棱角可借力拨转；拿 1 层「实心钨核」（`2.48kg`）即可正面碾压。 |
| **Q弹果冻怪**<br>`BouncerSlime` | `SphereShape3D`<br>`R = 0.66 m` | **`3kg`** | **`3.00 kg`** | `0.45` / `0.88` | `RigidBody3D` 锁定自转，由水平牵引力 + 坡向驻留力驱动左右巡逻 | 第一帧即按 `3kg` 超高弹球体真实碰撞并播放果冻压扁回弹形变；承受有效冲量（`J >= 3.2 N·s`）或气浪后解除巡逻与自转锁定，在跑道上Q弹滚跳留存。 |
| **漂浮软胶气球桩**<br>`AerialBlocker` (`soft_balloon`) | `SphereShape3D`<br>`R = 0.72 m` | **`250g`** | **`0.25 kg`** | `0.35` / `0.92` | `RigidBody3D`（`gravity_scale = 0`），受虚拟系留弹簧力跟随正弦轨迹微浮 | 正撞时被铁球轻快撞飞，侧面擦碰时凭 `0.92` 高弹性微偏空中球路；受撞脱锁后切为充气微重力（`gravity_scale = 0.28, linear_damp = 0.48`）轻飘弹落跑道留存。 |
| **磁浮配重铁块**<br>`AerialBlocker` (`mag_iron`) | `BoxShape3D`<br>`1.25 × 1.25 × 1.25 m` | **`12kg`** | **`12.00 kg`** | `0.82` / `0.16` | `RigidBody3D`（`gravity_scale = 0`），底部亮起青蓝磁浮环跟随正弦微浮 | 半空铁砧：轻球盲跳撞上会在空中严重受阻弹落；当承受显著撞击冲量（`J >= 4.5 N·s`）或爆炸气浪时磁浮断电（底部蓝环熄灭），恢复 `1.0x` 重力砸落木轨成为 `12kg` 地面重铁块！ |
| **铸铁大砝码**<br>`ShieldBrute` | `CylinderShape3D`<br>`R = 0.72 m, H = 1.40 m` | **`20kg`** | **`20.00 kg`** | `0.86` / `0.12` | 静置坡面 | 地面终极重物：未强化球无论多快正撞均被弹回，砝码仅微颤移位；唯受爆炸冲击波猛烈轰击或高重巨球冲撞才会翻滚移位甚至坠崖。 |

### 2.2 新增实体 `WoodenPin`（`800g` 榉木高球瓶）视觉与构造细节
- **视觉模型（程序化多段车削木柱，复用 `MaterialLibrary.make_beechwood_material` 与铸铁/红漆颈环装饰，Headless 自动跳过网格构建）**：
  1. 下半稳重瓶肚：`CylinderMesh`（底半径 `0.27 m`，中腹半径 `0.29 m`，高 `0.86 m`）；
  2. 收束瓶颈：`CylinderMesh`（顶半径 `0.13 m`，底半径 `0.25 m`，高 `0.36 m`），配一道醒目的复古橙红玩具漆环（高 `0.08 m`），提升远距离轮廓辨识度；
  3. 圆润瓶头：`SphereMesh`（半径 `0.18 m`，高 `0.38 m`）；
  4. 表面印字：瓶肚正反面与顶面通过 `MaterialLibrary.attach_weight_labels` 清晰标注 **`800g`**。
- **物理稳定性保障**：
  - 碰撞体采用平底 `CylinderShape3D`（`radius = 0.28 m, height = 1.56 m`）；
  - 开启 `center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM`，设 `center_of_mass = Vector3(0.0, -0.10, 0.0)`（质心离底面 `0.68 m`）。在 `11°` 斜坡上，重力投影偏移仅 $0.68 \times \tan 11^\circ \approx 0.132\text{ m} \ll 0.28\text{ m}$，保证未受撞时 100% 稳立不倒，受撞时干脆利落空翻倾覆。

### 2.3 固定件 `PinballBumper`（铆钉锁死弹球柱）真实接触化
- 移除原先半径 `0.95 m` 的隔空 `Area3D` 传感器与强制改写 `ball.linear_velocity.x` 的逻辑。
- 为 `PinballBumper`（`StaticBody3D`，半径 `0.72 m`，带 `FIXED` 铆钉法兰底座）配置高弹物理材质 `friction = 0.05, bounce = 0.95`，并加入分组 `"pinball_bumper"`。
- 当主角球真实接触 `PinballBumper` 圆柱表面时：触发硅胶套圈回弹缩放动画（`_ring_pulse = 1.0`），沿真实水平接触法线施加弹球电磁线圈径向弹射速度脉冲（保底法向弹速 `8.5 m/s`）及 `notify_wall_or_bumper_bounce` 前向奖励冲量；同时，翻滚过来的木箱、球瓶或果冻撞上 `PinballBumper` 也会基于 `bounce = 0.95` 自然高弹弹开。

---

## 3. 冲击波物理化与肉鸽词条接触冲量桥接

### 3.1 真实物理冲击波（爆炸桶 / 震地折射器 / 动能殉爆炉）
统一所有可动 `RigidBody3D` 障碍物的 `apply_shockwave(origin: Vector3, radius: float, force: float, chain_depth: int, ball: PlayerBall3D)` 接口：
- 当实体处于 `radius` 范围内时，计算距离衰减系数 $\text{falloff} = \text{clamp}(1.0 - \frac{d}{1.15 R}, 0.25, 1.0)$；
- 对该刚体解除驻坡/巡逻/悬浮锁定（`dislodge()`），并施加**真实物理冲量**（而非固定写死速度）：
  - 基准气浪冲量大小 $J_{\text{wave}} = \text{force} \times 0.85 \times \text{falloff}$（单位：$\text{N}\cdot\text{s}$），方向为水平径向背离爆心叠加赛道法向微上扬分量（`+0.42 * track_up`），并在质心上方 `+0.18 m` 偏心点通过 `apply_impulse` 注入自然翻滚角动量！
  - **自然质量分化**：同样一股 `25 N·s` 的气浪轰击下，`0.5kg` 小木块获得 `~50 m/s`（安全钳制至 `32 m/s` 上限防穿模）的剧烈掀飞，而 `20kg` 铸铁大砝码获得真实的刚体冲量被震移/掀翻，物理观感厚重可信。
- 若该障碍物此前尚未结算过有效破障（`not has_yielded_smash`）且气浪冲量达到该物体的有效扰动门限，则标记 `has_yielded_smash = true` 并调用 `ball.notify_obstacle_impact(entity_pos, chain_depth)` 参与词条连锁！

### 3.2 主角球真实碰撞监测与词条事件派发（`PlayerBall3D`）
在 `PlayerBall3D` 中保存每物理步积分前的球体线速度 `_pre_step_linear_vel`，并在 `_integrate_forces(state: PhysicsDirectBodyState3D)` 中遍历所有真实接触点：

1. **碰撞冲量提取**：
   - 对每个接触对象 `collider`，读取接触世界坐标 `contact_pos`、指向球体的接触法线 `contact_normal` 以及 Jolt 原生接触冲量向量 `state.get_contact_impulse(i)`（若冲量模长可用则直接取 $J = |\mathbf{J}_i|$，并以碰撞前后速度差 $m_{\text{ball}} |\mathbf{v}_{\text{post}} - \mathbf{v}_{\text{pre}}|$ 作为兜底校准）。
2. **「实心钨核（`tungsten_core`）」物理自洽化**：
   - 基础球（`smash_speed_loss_mult == 1.0`）：**零人工速度干预**，100% 原生 Jolt 刚体碰撞结果。
   - 持有「实心钨核」等降低碰撞掉速词条（`smash_speed_loss_mult < 1.0`）时：若与可动障碍物刚体碰撞导致沿赛道下坡前向（`-track_basis.z`）的速度损失 $\Delta v_{\text{fwd}} > 0.2\text{ m/s}$，则按减免比例 $(1.0 - \text{smash\_speed\_loss\_mult}) \times \Delta v_{\text{fwd}}$ 在本帧补偿前向动量（且补偿后总速率不超过碰撞前速率 `_pre_step_linear_vel.length()`，杜绝凭空刷速）。
3. **有效冲撞词条事件（`on_smash_target`）**：
   - 每个可动障碍物维护布尔状态 `has_yielded_smash: bool = false`。
   - 当主角球撞击可动障碍物的接触冲量 $J \ge J_{\text{trigger}}$（轻量物 `1.8 N·s`、中重物 `3.0 N·s`，确保轻轻蹭擦静止重物边缘不误触，真正发生明显撞飞/推翻/强冲击才触发）且 `not obstacle.has_yielded_smash` 时：
     - 标记 `obstacle.has_yielded_smash = true`（同一留存障碍物最多贡献 1 次词条充能与击飞计数，防止对着留在场上的重物反复蹭分，但物理刚体碰撞永久有效）；
     - 触发 `PlayerBall3D.notify_obstacle_impact(contact_pos, 0)` → 发射 `target_smashed`（震屏 + 计入结算统计）并派发 `synergy_bus.on_smash_target(ctx)`，完整驱动**「动能殉爆炉」「碎障续秒器」「动量过载」与「双相共振仪」**。
4. **刚性反弹词条事件（`on_wall_or_bumper_bounce`）**：
   - 除原有的护栏（`"track_rail"`）与固定弹球柱（`"pinball_bumper"`）外，当主角球撞在重物或高弹体（如 `20kg` 铸铁砝码、`12kg` 磁浮铁、`3kg` 果冻怪）上产生显著法向回弹（沿接触法线速度变化量 $\Delta v_n \ge 3.2\text{ m/s}$，带 `0.18s` 冷却）时，同样触发 `notify_wall_or_bumper_bounce(contact_normal, contact_pos, 0.0)`，使**「矢量折射核心」**也能借重物/果冻反弹顺滑折射出前向冲刺！
5. **词条文案微调对齐**：
   - 将 `UpgradeCatalog` 中原「撞碎障碍」措辞微调为更贴合真实物理留存的「冲撞障碍 / 撞飞目标」（属性键值、ID 与数值机制保持完全兼容）。

---

## 4. 赛道生成排布与确定性种子保障（`TrackGenerator3D`）

1. **三维分层刚体间距检测（`_is_rigidbody_pos_clear`）**：
   - 原逻辑仅按二维水平坐标 `Vector2(x, z)` 检查 `MIN_RB_CLEARANCE_XZ = 1.90 m`。当半空的 `AerialBlocker`（`Y ≈ 2.65 m`）与地面的 `BouncerSlime` 也升级为 `RigidBody3D` 后，改为**高度分层检查**：若两个刚体的局部高度差 `absf(pos.y - other.position.y) >= 1.50 m`（即地面层 vs 空中层），互不判定水平重叠，确保半空漂浮物正下方依然能自然摆放地面障碍或弹簧板；同层刚体之间继续严格保持 `>= 1.85 m` 水平净距（同一小瓶阵内的 `WoodenPin` 允许专属紧凑瓶距 `>= 0.92 m` 以支持多米诺连环倒瓶，同时与其他大刚体保持 `>= 1.85 m` 间距）。
2. **各区块障碍物合理化编排**：
   - **`StraightWide`（宽直道）**：混编斜摆 `500g`/`2kg` 木箱与 2~3 根一组的 `800g` `WoodenPin` 保龄球瓶阵，配合侧坡、`20kg` 铸铁砝码、`3kg` 果冻怪与 `1.5kg` 爆竹铁桶；
   - **`WaveHills`（波浪滑道）**：波谷中央布置 `1.5kg` 铁皮桶 + 两侧 `800g` 球瓶 / `500g` 木箱，飞跃波峰落地触发「震地折射器」或直接冲谷撞桶都能成片扫飞留在谷底翻滚；
   - **`NarrowBridge`（无护栏窄桥）**：移除原本易卡停轻球的重木箱，改为在第 2 关起放置 `800g` `WoodenPin` 或 `500g` 轻木块，撞击后球瓶/轻木翻落悬崖视觉反馈极佳且绝不堵死窄桥；
   - **`SplitPath` / `RampGap` / `PinballAlley` / `FunnelGauntlet`**：按各自节奏穿插 `WoodenPin` 瓶组与斜角木箱。
3. **100% 确定性种子隔离不变**：
   - 所有新增的木箱摆放偏转角（`yaw_deg`）与球瓶生成均严格且唯一消耗 `generate_track` 局部 `rng`（由 `RunState.derive_track_seed(run_seed, level)` 派生），保证同一种子在任意次重玩及跨关选卡后生成的地形、实体类型、坐标、朝向与浮动初相位 100% 精确一致。

---

## 5. 代码模块变更清单

```text
src/
  core/
    material_library.gd           # 新增 make_charred_husk_material()（焦黑空铁桶）与球瓶装饰漆环材质辅助
  gameplay/
    player_ball_3d.gd             # 新增 _integrate_forces 真实接触冲量采集、钨核前向动量减损补偿、notify_obstacle_impact 与重物反弹桥接
    game_world_3d.gd              # 适配爆炸冲击波刚体物理推动与深渊实体安全遍历
  track/
    track_generator_3d.gd         # 三维分层刚体净距检查、木箱确定性微偏转摆放角、窄桥去重箱、编排 800g WoodenPin 球瓶阵
    entities/
      track_entity_factory.gd     # 新增 create_wooden_pin(pos)，扩展 create_crate 支持 yaw_deg
      crate_obstacle.gd           # 移除假传感器与 0.75s 销毁；2.0kg 中箱、双态驻坡/翻滚阻尼、真实气浪冲量与深渊回收
      wooden_pin.gd               # [新增] 800g 榉木高球瓶 RigidBody3D（低质心稳立 11° 坡面、抄底空翻倾覆、倒地顺坡滚扫）
      shield_brute.gd             # 移除假传感器与改速位移；纯 20kg 铸铁圆柱刚体、真实气浪受击与深渊回收
      bouncer_slime.gd            # 重构为 3kg 高弹球形 RigidBody3D（物理牵引巡逻、受撞脱锁Q弹翻滚留存、保留果冻压扁动画）
      aerial_blocker.gd           # 重构为 RigidBody3D（250g 高弹气球 / 12kg 磁浮铁块，虚拟弹簧悬浮、受撞脱锁飘落/断电砸地留存）
      explosive_barrel.gd         # 移除外扩传感器改为桶身真实接触引爆；炸后变 0.45kg EMPTY 焦黑空桶刚体飞出留存，对周围刚体施加真实爆炸冲量
      pinball_bumper.gd           # 移除外扩传感器，配置 bounce=0.95 物理材质，基于真实圆柱表面接触触发径向弹射与脉冲动画
  upgrades/
    upgrade_catalog.gd            # 微调破障相关描述文案以匹配真实冲撞留存表现
tests/
  test_entities.gd                # 全面升级单测：验证 7 类实体真实刚体属性、碰撞不消失留存、空桶残骸、气球/磁铁脱锁落地、球瓶稳驻与倾覆滚落
  test_track_generator.gd         # 验证三维分层净距、WoodenPin 生成、窄桥轻量化及同种子坐标/旋转角 100% 确定性
  test_ball_and_gravity.gd        # 验证真实碰撞动量质量比响应与钨核减损补偿
  test_game_loop.gd               # 验证 SEED_INPUT 冻结刚体巡逻/悬浮、冲击波连锁及构筑实机模拟优势
```

---

## 6. 测试与验收标准

1. **真实质量比与形状碰撞测试（Headless Jolt 3D 物理帧实测）**：
   - 验证 `1.5kg` 球在斜坡/平地上撞击 `500g` 轻箱、`800g` 球瓶、`2.0kg` 重箱、`3.0kg` 果冻、`20kg` 大砝码时，碰撞后球速严格随目标质量递增而单调递减（`1.5kg` 正撞 `20kg` 必产生向后反弹速度，`500g` 轻箱获得显著前向飞出速度）。
   - 验证 `800g` `WoodenPin` 在 `-11°` 坡面上静置 40 物理帧不倾倒、不溜坡；被小球撞击后发生显著绕轴倾覆旋转（倾角 `> 45°`）并留在跑道上继续运动。
2. **全员留存与零凭空消失测试（Headless）**：
   - 验证木箱、球瓶、果冻怪、大砝码、被撞落的 `250g` 气球 / `12kg` 磁浮铁块以及引爆后的 `0.45kg` 焦黑空铁皮桶，在遭受碰撞或爆炸冲击波并模拟 `2.0 秒`（`120` 物理帧，远超旧版 `0.75s`）后，只要仍在跑道面上，全部保持 `is_instance_valid`、`visible == true` 且碰撞层激活（不穿穿模掉下跑道地板）。
   - 验证实体跌落至赛道局部 `Y < -28.0m` 深渊后正确自动销毁。
3. **特殊实体状态转换测试（Headless）**：
   - 验证 `ExplosiveBarrel` 引爆前为 `1.5kg`（印字 `"1.5kg"`），被球或高速翻滚刚体撞击引爆后 `is_detonated == true`、质量变为 `0.45kg`（印字 `"EMPTY"`），不销毁且不会二次引爆，同时将周围刚体真实震飞。
   - 验证 `AerialBlocker` 未撞前维持确定性正弦微浮，受撞脱锁后 `250g` 气球以低重力飘落、`12kg` 磁浮铁恢复 `1.0x` 重力砸落跑道面且底部磁浮环隐藏。
   - 验证 `BouncerSlime` 未撞前左右物理巡逻，受强撞后解除巡逻自由翻滚弹跳。
4. **词条联动与确定性种子回归测试（Headless + 实机画面核验）**：
   - 验证单个障碍物被撞飞仅触发 1 次 `on_smash_target`（不重复刷分），「动能殉爆炉」「碎障续秒器」「实心钨核」「矢量折射核心」全链路正常生效；
   - 验证全套自动化测试 100% 零报错通过，且导出刷新 Web HTML5 构建包。
