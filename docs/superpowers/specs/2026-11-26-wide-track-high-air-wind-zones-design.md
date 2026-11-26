# 《给我滚》跑道 25% 扩宽、高空亚克力天桥与全三维无差别物理风场设计文档

- **日期**：2026-11-26
- **前置架构**：
  - `docs/superpowers/specs/2026-11-25-tabletop-visual-physics-verticality-design.md`
  - `docs/superpowers/specs/2026-11-26-real-physics-persistent-obstacles-design.md`
- **引擎与平台**：Godot 4.6（`gl_compatibility` 渲染器，Jolt Physics 3D，兼容桌面端原生与 Web HTML5 导出）
- **核心设计目标**：
  1. **跑道全谱系等比扩宽 +25%**：将标准主跑道宽度从 `10.0m` 提升至 **`12.5m`**，同步等比放大全部 7 类区块宽度、护栏、斜坡、分流岛、终点拱门及横向障碍排布范围，为侧风对抗、擦边撞角与高空错位天桥提供充裕的横向空间。
  2. **高空层（`Y = 4.4m ~ 6.8m`）稀疏随机地形与障碍**：填补高飞抛物线顶端的空间空白，以低密度随机生成不遮挡地面视线的**半透明磨砂亚克力高空天桥（`SkyPlatform`）**与稀疏高空星环/路障，支持弹簧板、斜坡高速起跳或上升热气流登顶，并让天桥上被撞飞/吹落的积木与球瓶真实砸向下层跑道。
  3. **区域随机全三维可见风场（`WindZone`）**：在地面跑道与半空/高空随机布置具备清晰流光风带与方向箭头标的区域风场（含左右侧风、顺/逆风、上升热气流与高空侧下压风），**无差别对风区内一切真实刚体施加气动力**（轻气球飘飞、小木块滑移、高球瓶迎风倾倒滚落，`20kg` 铸铁砝码靠真实自重静摩擦稳如泰山），并与词条「顺风帆装甲」形成深度物理联动。

---

## 1. 模块一：跑道全尺寸 +25% 等比扩宽与视野适配

### 1.1 区块与静态结构尺寸对照表（`×1.25`）

| 结构/区块 | 原尺寸参数 | 扩宽 +25% 后精确参数 | 说明 |
| :--- | :--- | :--- | :--- |
| **`TrackChunkBase.STANDARD_WIDTH`** | `10.0 m`（护栏 `±5.2 m`） | **`12.5 m`**（护栏 `±6.45 m`） | 应用于 `StraightWide`、`WaveHills`、`PinballAlley`、`FunnelGauntlet`、`RampGap` 出入口主道 |
| **起点安全平台 (`_build_start_platform`)** | 宽 `10.0 m`，后挡墙 `10.4 m` | **宽 `12.5 m`**，侧护栏 `±6.45 m`，后挡墙 `12.9 m` | 开局起步视野更舒展 |
| **终点拱门与缓冲道 (`_build_finish_archway`)** | 跑道宽 `12.0 m`，立柱 `±5.4 m`，横梁 `11.5 m` | **跑道宽 `15.0 m`**，立柱 `±6.75 m`，横梁 `14.4 m` | 终点判定 `Area3D` 扩至 `28.0 × 20.0 × 3.5 m`（兼容高空冲线！） |
| **`NarrowBridge`（无护栏窄桥）** | 过渡段 `8.0 m`，窄桥 `4.2 m`（边条 `±2.04 m`） | **过渡段 `10.0 m`**，窄桥 **`5.25 m`**（边条 `±2.55 m`） | 侧风吹拂窄桥时留有逆风救球余地 |
| **`SplitPath`（双岔路）** | 总宽 `11.2 m`（护栏 `±5.8 m`），分道中心 `±3.1 m` | **总宽 `14.0 m`**（护栏 `±7.2 m`），分流岛宽 `1.6 m`，分道中心 **`±3.85 m`** | 右道减速胶滩同步扩至 `4.5 × 10.0 m` |
| **`RampGap`（断桥大跳台）** | 中央跳坡 `5.2 m`，两侧辅桥 `±4.1 m`（宽 `1.8 m`） | **中央跳坡 `6.5 m`**，两侧辅桥 **`±5.125 m`**（宽 `2.25 m`） | 起跳对准容错更自然 |
| **`FunnelGauntlet`（漏斗阵）** | 内斜导流墙 `±3.8 m` | **内斜导流墙 `±4.75 m`** | 漏斗收束比例与 `12.5 m` 跑道严格匹配 |
| **`SideLaunchRamp`（侧边起飞小斜坡）** | 宽 `2.4 m`，位置 `±3.2 m` | **宽 `3.0 m`**，位置 **`±4.0 m`** | 紧贴加宽后的外侧车道，主道更通畅 |

### 1.2 横向生成边界、安全复位与追尾相机同步
1. **横向生成与刚体防重叠边界（`TrackGenerator3D`）**：
   - 各区块内木箱、球瓶阵、弹簧板、铁皮桶及 `PinballBumper`（`±2.75 m`）的横向分布坐标同步乘 `1.25`；
   - `BouncerSlime` 默认巡逻半宽由 `2.8 m` 扩至 **`3.5 m`**；
   - `_resolve_rigidbody_clearance` 的安全横向搜索钳制范围由 `[-3.8, 3.8]` 扩至 **`[-4.8, 4.8]`**。
2. **安全复位锚点窗口（`PlayerBall3D`）**：
   - 地面安全复位采样宽度由 `absf(local_pos.x) <= 2.4` 扩至 **`<= 3.0`**。
3. **零横滚广角跟拍微调（`ChaseCamera3D`）**：
   - `FOLLOW_OFFSET` 微调为 `Vector3(0.0, 5.6, 8.8)`（原 `(0.0, 5.2, 8.2)`），俯仰角保持 `-27.0°`、横滚角严格恒定 `0.0°`，同时完整收纳 `12.5m` 宽跑道与头顶 `4.5m ~ 6.8m` 高空层。

---

## 2. 模块二：高空层（`Y = 4.4m ~ 6.8m`）稀疏地形与障碍

### 2.1 半透明磨砂亚克力高空天桥（`TrackChunkBase.add_sky_platform`）
- **定位与空间分层**：
  - 全赛道空间正式划分为三层：**地面层（`Y = 0.0 ~ 1.5m`）**、**低空层（`Y = 2.5 ~ 3.0m`）**、**高空层（`Y = 4.4 ~ 6.8m`）**。各层高度间隔均超过 `MIN_RB_LAYER_DIFF_Y = 1.50m`，高空刚体与低空/地面刚体的水平槽位互不干扰。
- **几何与材质规范**：
  - 接口：`add_sky_platform(local_pos: Vector3, size: Vector3 = Vector3(3.8, 0.34, 11.5), with_end_kick: bool = false) -> StaticBody3D`。
  - 桥面采用暖金琥珀或清透冰青色半透明磨砂亚克力（`MaterialLibrary.make_frosted_acrylic_material`，透明度 `~0.68`），物理材质 `friction = 0.80, bounce = 0.14`，加入分组 `"sky_platform"` 并标记 `is_anchored_fixed = true`。
  - 两侧边缘配 `0.10m` 低矮发光导流沿（防轻微偏滑，同时允许被撞飞的积木/球瓶翻落天桥砸向下层！）；若 `with_end_kick == true`，在天桥 `-Z` 出口端衔接一段长 `2.6m`、上扬 `+12°` 的亚克力小挑板。
  - 支撑视觉：仅在桥面两侧外沿向下延伸纤细半透明/黄铜悬吊拉索装饰（无实体碰撞），绝不阻挡地面行球路线与玩家视线。

### 2.2 低密度高空生成策略与天降连锁玩法
- **生成密度控制（克制、清爽、有惊喜）**：
  - 除开局第 1 块缓冲区块与 `NarrowBridge` 外，其余区块按确定性种子以 **`32%`（第 1 关）~ `48%`（第 4 关起）** 的概率生成 1 处高空要素（高空亚克力天桥或纯高空航道组合），保证空域有层次而不杂乱。
- **高空布置组合**：
  1. **天桥落物套餐**：在 `SkyPlatform`（`Y = 4.5m ~ 5.4m`）桥面上放置 1 枚高空 `AerialBonusRing`（`+0.8s` + 空中推进）+ 末端 2 根 `800g` `WoodenPin` 球瓶或 `500g` 轻木块（或第 3 关起偶现 `1.5kg` 爆竹铁皮桶）。玩家飞上天桥冲撞或高空风吹过时，球瓶/木块/空铁桶会从 `5m` 高空坠落砸进下层跑道障碍群！
  2. **高空跳越点缀**：在 `WaveHills` 大波峰、`RampGap` 大跳台或地面**上升风场**正上方的高抛物线顶点（`Y = 4.8m ~ 6.4m`），稀疏点缀 1 枚高空星环与 1 个偏置高空 `AerialBlocker`（`250g` 高空气球或第 3 关起 `12kg` 高空磁浮铁块）。
- **终点拱门高空冲线保障**：
  - `_build_finish_archway` 的终点触发 `Area3D` 高度上延覆盖 `Y ∈ [-2.0m, +18.0m]`，确保玩家从高空天桥一跃冲过终点上空时同样 100% 灵敏过关。

### 2.3 任意高度平台真实落地识别（`PlayerBall3D`）
- 在 `PlayerBall3D._integrate_forces` 中检测当前帧是否存在与静态承重面（非 `"track_rail"`、非可动刚体，且接触法线满足 `contact_normal.dot(track_basis.y) >= 0.62`）的真实物理接触，维护状态 `_has_surface_support: bool`（带 `0.06s` 微缓冲防单帧抖动）。
- 升级离地与落地判定：
  - 当小球从高空落到 `Y = 5.0m` 的 `SkyPlatform` 桥面时，`_has_surface_support` 变为 `true`，立即正常结算 `on_land`（触发「震地折射器」环形冲击波与前向折射冲刺！），并在天桥上享有完整的地面侧推操控与横向止滑手感；驶离天桥边缘再次进入腾空态。

---

## 3. 模块三：区域随机全三维可见风场（`WindZone`）

### 3.1 `WindZone` 实体接口与五类三维风向预设
新建 `src/track/entities/wind_zone.gd`（`class_name WindZone extends Area3D`），由 `TrackEntityFactory.create_wind_zone(pos: Vector3, zone_size: Vector3, preset: String, force_newtons: float)` 创建：

| 预设标识 `preset` | 赛道局部风向矢量 `wind_dir_local` | 基准风力 `force_newtons` | 视觉色相 | 典型投放位置与物理体验 |
| :--- | :--- | :--- | :--- | :--- |
| **`"cross_left"`** | `Vector3(-1.0, 0.0, 0.0)` | `22.0 ~ 30.0 N` | 清透青白 | 地面主道/窄桥/半空：将球与轻积木、球瓶吹向左侧 |
| **`"cross_right"`** | `Vector3(1.0, 0.0, 0.0)` | `22.0 ~ 30.0 N` | 清透青白 | 地面主道/窄桥/半空：将球与轻积木、球瓶吹向右侧 |
| **`"tailwind"`** | `Vector3(0.0, 0.0, -1.0)` | `24.0 ~ 34.0 N` | 翠青亮绿 | 直道/分流道/高空走廊：顺风风洞强力推射球与松动路障 |
| **`"headwind"`** | `Vector3(0.0, 0.0, 1.0)` | `18.0 ~ 25.0 N` | 暖琥珀橙 | 局部半幅车道（留出绕行或起跳空间）：迎面强风减速并吹倒轻球瓶 |
| **`"updraft"`** | `Vector3(0.0, 0.94, -0.34)` | `40.0 ~ 48.0 N` | 翠绿上升光 | 高空天桥前下方/断桥谷底：强劲上升热气流，将 `1.5kg` 球（及轻木块/气球）直接托举吹上 `5m+` 高空天桥！ |
| **`"high_downdraft"`** | `Vector3(±0.45, -0.89, 0.0)` | `20.0 ~ 26.0 N` | 暖琥珀橙 | 仅高空层稀疏刷出：高空斜下压气流，考验空中微调保持高度 |

### 3.2 无差别真实气动力公式与肉鸽词条联动
在 `WindZone._physics_process(delta)` 中，计算当前世界空间单位风向 $\hat{\mathbf{w}} = (\text{global\_basis} \cdot \text{wind\_dir\_local}).\text{normalized}()$，对区域内所有有效 `RigidBody3D` 无差别施加气动力：

1. **主角金属球（`PlayerBall3D`）**：
   - 迎风面积缩放系数 $A_{\text{ball}} = (\text{current\_radius} / 0.55)^{1.5}$（变大巨球迎风面积更大）。
   - 基础风力 $\mathbf{F}_{\text{base}} = F_0 \cdot A_{\text{ball}} \cdot \hat{\mathbf{w}}$。
   - **联动词条「顺风帆装甲（`tailwind_sail`）」**：读取 `ext_mult = synergy_bus.stats.get_stat("external_boost_mult")`。当 `ext_mult > 1.0` 时，提取 $\mathbf{F}_{\text{base}}$ 沿下坡前向（$-\text{track\_basis.z}$）与上升法向（$+\text{track\_basis.y}$）的正向有利分量并乘以 `ext_mult`，让「顺风帆装甲」在顺风带与上升气流中化身真正的强力风帆！
   - 调用 `ball.apply_central_force(final_force)`。
2. **场内一切其他 `RigidBody3D` 障碍物（无差别吹拂）**：
   - 按实体物理轮廓匹配等效迎风系数 $A_{\text{eff}}$：
     - `AerialBlocker`（`250g` 气球）：$A_{\text{eff}} = 1.15$。若气球仍处于悬停系留态且 $F_0 \cdot A_{\text{eff}} \ge 12.0\text{ N}$，强风直接吹断气球系留（`untether()`），使其顺风轻盈飘走！而 `12kg` 磁浮铁块因磁浮锁定阈值高，未断电前保持稳固，断电坠落期间受真实风力。
     - `WoodenPin`（`800g` 高球瓶）：$A_{\text{eff}} = 0.95$。当气动力 $F > 9.5\text{ N}$ 时唤醒刚体（`dislodge()`），并将风力作用在沿瓶身向上 `+0.28m` 的偏心点（`apply_force(f_vec, pin_up * 0.28)`），产生真实倾覆风矩把高球瓶吹倒并在坡面上顺风滚动！
     - `CrateObstacle`：`500g` 轻木箱 $A_{\text{eff}} = 0.90$（$F > 9.0\text{ N}$ 时突破静摩擦 `dislodge()` 被风吹滑翻滚）；`2kg` 重木箱 $A_{\text{eff}} = 1.05$（常规风力下靠 `2kg` 木板静摩擦稳住，特强风或碰撞失稳后顺风滑移）。
     - `ExplosiveBarrel`：$A_{\text{eff}} = 0.92$（未引爆 `1.5kg` 桶在常规风下稳驻，引爆后的 `0.45kg` `"EMPTY"` 空铁皮桶会被风吹得满场叮当乱滚！若被狂风吹飞的木块/球瓶以 `> 2.6 m/s` 撞上铁桶，甚至能**借风力自动引爆铁皮桶**！）。
     - `ShieldBrute`（`20kg` 铸铁大砝码）与 `BouncerSlime`（`3kg`）：同样无差别调用 `apply_central_force`（`20kg` 大砝码因静摩擦力 `> 350 N` 在任何风场中纹丝不动，完美体现真实物理质量对比；已脱锁翻滚的 `3kg` 果冻球则随风偏转）。

### 3.3 明亮清晰的风洞视觉设计（`gl_compatibility` 与 Headless 安全）
`WindZone` 在非 Headless 模式下构建 `_visual_root`（局部坐标系对齐 `wind_dir_local`）：
1. **12 条循环流动半透明流光风带（Animated Wind Ribbons）**：
   - 在 `zone_size` 盒体截面内均匀错位排布 12 条细长发光半透明 `BoxMesh` 流线（长 `1.8m ~ 2.6m`，截面 `0.045m`）。
   - 每帧按风速 `scroll_speed = clampf(wind_force_newtons * 0.42, 6.0, 18.0)` 沿风向连续推进相位 $t \in [0, 1)$，并在两端 `18%` 区间使用 $\sin(\pi t)$ 平滑缩放宽度与长度，实现无接缝的风洞流线穿梭感（`SEED_INPUT` 暂停时随 `track_generator.process_mode` 自动静止）。
2. **三维立体风向标箭头组（Directional Wind Chevrons）**：
   - 在风区前、中、后布置 3 枚半透明发光楔形箭头（`PrismMesh` 指向精确三维风向），辅以极淡的风区底边导流细框，让玩家在远处 `40m` 外扫一眼就能同时判断**风区边界、风向（左/右/前/后/上）与风力强弱**。

---

## 4. 代码模块变更清单

```text
src/
  gameplay/
    chase_camera_3d.gd            # FOLLOW_OFFSET 微调至 (0.0, 5.6, 8.8) 适配 +25% 宽跑道与高空层视野
    player_ball_3d.gd             # 安全复位窗口扩至 ±3.0m；_integrate_forces 新增任意高度平台真实支撑识别 (_has_surface_support) 驱动高空天桥落地与操控
  track/
    track_chunk_base.gd           # STANDARD_WIDTH 升至 12.5m 及全区块几何 ×1.25；新增 add_sky_platform(...) 半透明亚克力高空天桥构建器
    track_generator_3d.gd         # 起点/终点/全区块横向排布 ×1.25、防重叠边界扩至 ±4.8m、低密度高空天桥与高空路障编排、地面与空中随机 WindZone 编排
    entities/
      wind_zone.gd                # [新增] 区域三维风场 Area3D：无差别真实气动力、球瓶吹倒风矩、气球吹断系留、顺风帆联动与 12 路动态流光风带视觉
      track_entity_factory.gd     # 新增 create_wind_zone(...) 工厂方法，更新 BouncerSlime 默认巡逻半宽至 3.5m
  upgrades/
    upgrade_catalog.gd            # 「顺风帆装甲」描述补充区域顺风/上升气流加成说明
tests/
  test_entities.gd                # 新增 WindZone 单元测试：三维风力推动小球、顺风帆乘算、无差别吹走 500g 箱/吹倒 800g 球瓶/吹飞 250g 气球且 20kg 砝码稳驻
  test_ball_and_gravity.gd        # 更新相机偏移断言；新增高空 SkyPlatform 真实着陆触发 on_land 与天桥操控测试
  test_track_generator.gd         # 验证 STANDARD_WIDTH == 12.5m、全区块加宽、SkyPlatform 高空层与 WindZone 生成及同种子 100% 确定性
  test_game_loop.gd               # 验证风区外驻坡稳定性、SEED_INPUT 暂停风带与刚体、全链路模拟回归
```

---

## 5. 测试与验收标准

1. **跑道 +25% 扩宽验证（Headless）**：
   - 验证 `TrackChunkBase.STANDARD_WIDTH == 12.5`，`NarrowBridge` 窄桥宽 `5.25m`、`SplitPath` 总宽 `14.0m`、`RampGap` 主跳坡宽 `6.5m`，且全等级多下坡区块无缝拼接、同层刚体净距全部达标。
2. **高空天桥与高空落地验证（Headless Jolt 3D 实测）**：
   - 验证生成的赛道包含高空层 `SkyPlatform`（`Y >= 4.4m`）与高空稀疏实体，且与低空/地面层互不重叠；
   - 验证 `PlayerBall3D` 从高处落到 `Y = 5.0m` 的 `SkyPlatform` 上时，准确识别支撑面并触发 `on_land`（「震地折射器」正常释放冲击波与前向冲刺），驶出天桥边缘后恢复腾空态。
3. **三维风场无差别物理与词条联动验证（Headless Jolt 3D 实测）**：
   - 验证侧风（`±X`）、顺/逆风（`±Z`）与上升热气流（`+Y`）对 `PlayerBall3D` 产生准确对应方向的速度变化（上升热气流可将 `1.5kg` 球从地面吹升至 `Y > 4.5m`）；持有「顺风帆装甲」时顺风/上升助推效果显著高于无词条球；
   - 验证同一强风场内无差别物理分化：`500g` 轻木箱被吹移、`800g` `WoodenPin` 被吹倒、`250g` 气球被吹断系留飘走，而 `20kg` `ShieldBrute` 位移接近 `0`（稳如泰山）。
4. **全量回归与 Web HTML5 构建包刷新**：
   - `./scripts/test.sh` 全套件 100% 零报错通过，并执行 `./scripts/build-web.sh` 刷新 `web/` 导出产物。
