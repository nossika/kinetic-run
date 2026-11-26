# 《给我滚》柔和黏土绘本风全链路视觉重构设计文档

- **日期**：2026-11-26
- **前置架构**：
  - `docs/superpowers/specs/2026-11-25-tabletop-visual-physics-verticality-design.md`
  - `docs/superpowers/specs/2026-11-26-wide-track-high-air-wind-zones-design.md`
- **引擎与平台**：Godot 4.6（`gl_compatibility` 渲染管线，Jolt Physics 3D，兼容桌面端与 Web HTML5 导出，兼容 `--headless` 单元测试）
- **核心设计目标**：
  1. **彻底消除“白模棱角与 Demo 拼凑感”**：新增程序化圆角网格生成器（`ClayMeshBuilder`），将全场景生硬的 90° 直角 `BoxMesh`、低面数八棱柱与尖锐三棱柱全面升级为**温润胖圆角盒体、倒角圆顶柱、胶囊圆木护栏与鹅卵石果冻软垫**；
  2. **大幅视觉降噪，突出跑道焦点**：移除底部 `260×360m` 深棕木缝网格大板（`WorkbenchBackdrop`），全面取消黑黄警示斜纹法兰、六角螺栓与 `"FIXED"` 标签，并将障碍物双面粗黑描边重量标签精简为**单面同色系柔和“木刻/陶印”微字**；
  3. **统一「柔和黏土绘本风」材质、光影与 `gpt-image` 资产**：利用 `gpt-image` 重新绘制全套低噪点手绘浅枫木纹、软木积木纹、哑光软陶颗粒纹、珊瑚彩绘桶纹与水彩晴空云海背景；结合**半兰伯特暖调柔光（Half-Lambert Wrap）+ 边缘菲涅尔柔光 + 暖米色空气透视柔雾**，统一低饱和暖色调；
  4. **极简萌感点缀与绘本羊皮纸 UI 融合**：为生命体类障碍（果冻怪、重装铁卫、空中路障）点缀克制可爱的**手作软陶豆豆眼**（静态木艺器物保持纯粹圆润质感）；将暗黑赛博 HUD、选牌与结算面板同步重构为**温暖奶油羊皮纸大圆角卡片**，且物理碰撞手感与单元测试 100% 零回归。

---

## 1. 模块一：绘本晴空环境、暖调柔光着色与 `gpt-image` 资产矩阵

### 1.1 环境大降噪：水彩云海晴空 + 暖调远景柔雾（`GameWorld3D` & `project.godot`）
- **移除高频木桌背景**：
  - 删除 `GameWorld3D` 中的 `_workbench_backdrop`（`260×360m` 木纹平板及 30+ 根纵横深色接缝木条）及其每帧跟随同步逻辑，根除高速滚动时的背景频闪与前景同色缠绕。
- **绘本暖空与绵云背景**：
  - 使用 `PanoramaSkyMaterial`（加载 `res://assets/textures/storybook_sky_clouds.png`）或定制暖奶油渐变 `ProceduralSkyMaterial`（天顶柔粉蓝 `#8EC5E8`、天际暖奶油杏白 `#FBF0DF`、地面柔和暖驼粉 `#EAD6BE`），让浅木跑道干净悬浮于温润绘本晴空中。
  - 环境光源改为 `Environment.AMBIENT_SOURCE_SKY`（能量 `0.62`，搭配暖色天际漫反射），使所有物体暗部自然吸入温暖天空与奶白色地面反弹光，彻底消除死黑灰冷阴影。
- **空气透视深度柔雾（Depth Fog）与抗锯齿升级**：
  - 在 `WorldEnvironment` 启用柔和暖奶油雾效（`fog_enabled = true`，`fog_light_color = Color(0.97, 0.92, 0.85)`，`fog_density` / 深度区间覆盖 `48m ~ 145m`，`fog_sky_affect = 0.18`），自然弱化远处区块细节密度，突出眼前 `30m` 跑道决策区。
  - 主平行光（`MainSunLight`）调整为温暖晨光色温 `Color(1.0, 0.95, 0.87)`，辅以柔和暖蓝补光（`SkyFillLight`，能量 `0.32`）；`project.godot` 中将 `anti_aliasing/quality/msaa_3d` 由 `1`（2x）提升至 `2`（4x MSAA），柔化几何边缘。

### 1.2 暖调半兰伯特软陶柔光材质体系（`MaterialLibrary`）
- **原生兼容性与测试契约保持**：
  - 保留 `MaterialLibrary` 全部既有静态工厂方法签名与 `StandardMaterial3D` 返回类型，100% 兼容 `gl_compatibility` WebGL2 管线与 `tests/test_core_stats.gd` 材质属性断言。
  - 在 `_new_base_material()` 中统一启用 **半兰伯特暖调漫反射包裹（`diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP`）** 与柔和 **边缘菲涅尔柔光（`rim_enabled = true, rim = 0.24, rim_tint = 0.35`）**，使光影明暗交界线呈丝滑软陶过渡，同时严格保持各材质原有的 `metallic` / `roughness` / `transparency` 契约区间以兼容单元测试断言。
- **低饱和绘本暖色盘规范**：
  - **主跑道 / 波浪木坡**：奶油浅枫木（`Color(0.96, 0.90, 0.81)` 柔和提亮，摒弃原先发暗偏黄棕的厚重色调）；
  - **护栏 / 加速带 / 顺风 / 穿环**：鼠尾草薄荷绿（`#7AD4B4`）与暖奶油白（`#FAF3E6`）；
  - **高空云朵跳板 / 侧跳台 / 侧风**：雾霭粉蓝（`#86C2E6`）配暖白圆润包边；
  - **弹簧板 / 奖励内环**：暖阳鹅黄（`#F7CA65`）；
  - **弹珠蘑菇圈 / 啵啵炸弹桶 / 逆风**：柔和珊瑚蜜桃红（`#EE7864`）；
  - **软陶重物 / 主角球**：温润深暖陶灰（`#5B606B`）与釉面陶瓷银蓝（`#7B8DA4`）。

### 1.3 `gpt-image` 手绘肌理贴图资产表（`assets/textures/`）
使用 `.agents/skills/gpt-image/scripts/generate.py` 生成风格高度统一、低噪点、无生硬黑边的绘本手作贴图：

| 资源路径 | 尺寸 | 视觉特征与用途 |
| :--- | :--- | :--- |
| `res://assets/textures/track_beechwood.png` | `1024×1024` | 温润低对比手绘奶油浅枫木纹，柔和顺滑无黑结噪点，用于主跑道与木瓶 |
| `res://assets/textures/crate_balsa_wood.png` | `1024×1024` | 温暖手作圆润木积木面纹理，带柔和浅内凹圆角框细节，用于轻/重积木箱 |
| `res://assets/textures/metal_cast_iron.png` | `1024×1024` | 细腻手作哑光软陶/彩绘陶铁微肌理（替代粗糙黑铸铁），用于主角球、重锤与磁浮块 |
| `res://assets/textures/barrel_retro_hazard.png` | `1024×1024` | 绘本童话风珊瑚蜜桃红与奶油白柔和宽条纹彩绘贴图，用于啵啵炸弹桶 |
| `res://assets/textures/jelly_bubble_soft.png` | `1024×1024` | 清透柔和的水果奶昔软糖微气泡柔光贴图，用于果冻怪与减速软垫 |
| `res://assets/textures/anchor_hazard_stripe.png` | `1024×1024` | 温润浅陶土压纹肌理贴图（替换原刺眼黑黄斜纹，保持常量路径兼容测试） |
| `res://assets/textures/storybook_sky_clouds.png` | `1536×1024` | 治愈系绘本水彩粉蓝晴空与绵软暖白流云环境全景贴图，用于世界天空背景 |

---

## 2. 模块二：程序化圆角网格库（`ClayMeshBuilder`）与全实体造型重塑

### 2.1 `ClayMeshBuilder` 核心接口与网格缓存（`src/core/clay_mesh_builder.gd`）
- **Headless 安全与零冗余分配**：
  - 当 `DisplayServer.get_name() == "headless"` 时，所有网格生成函数直接返回 `null`（与 `RenderHelper.attach_mesh` 协同，保持自动化测试毫秒级速度）。
  - 非 Headless 模式下，将输入尺寸量化到 `0.005m` 精度拼装为缓存键存入静态 `_mesh_cache: Dictionary`，相同规格的跑道板、积木箱、底座在整局游戏内共享唯一 `ArrayMesh` 实例。
- **四大程序化圆润网格原语**：
  1. `make_rounded_box(size: Vector3, bevel_radius: float = 0.14, bevel_segments: int = 3) -> ArrayMesh`：
     - 基于三轴分段球面法线偏移构建平滑圆角立方体（自动将 `bevel_radius` 钳制在 `min(size.x, size.y, size.z) * 0.45` 以内），输出解析平滑法线与标准六面/比例 UV，彻底消灭 90° 硬折边。
  2. `make_chamfered_cylinder(top_radius: float, bottom_radius: float, height: float, bevel: float = 0.08, radial_segments: int = 24) -> ArrayMesh`：
     - 生成上下顶盖带圆弧过渡的温润圆台/圆饼网格，用于炸弹桶、重装铁卫躯干、弹簧顶垫与陶土吸盘底座。
  3. `make_pebble_pad(size_xz: Vector2, height: float = 0.10, radial_segments: int = 24) -> ArrayMesh`：
     - 生成饱满扁圆鹅卵石/水滴状有机软垫网格，用于 `SlimeZone` 果冻水洼与 `BoostPad` 加速软垫。
  4. `attach_clay_eyes(parent: Node3D, forward_pos: Vector3, eye_spacing: float = 0.24, eye_radius: float = 0.065, with_blush: bool = true) -> Node3D`：
     - 挂载一对克制可爱的手作软陶豆豆眼（深可可褐哑光圆珠 + 右上方微小白瓷高光点 + 两侧极淡蜜桃粉椭圆腮红贴片），统一面向 `+Z` 追尾镜头方向。

### 2.2 赛道结构、跳台与固定底座降噪（`TrackChunkBase` & `TrackGenerator3D`）
- **温润圆边木滑道与胶囊护栏**：
  - `_add_floor_slab` 改用 `ClayMeshBuilder.make_rounded_box(size, 0.14, 3)`，使跑道侧沿与接缝呈现柔和手作木板圆角；`_add_speed_stripes` 改为浅奶油色扁平圆角木镶条（降低金属反光，融入木面）。
  - `_add_guard_rail` 摒弃薄片荧光亚克力直角墙，改用柔和暖奶油/鼠尾草绿/雾霭粉蓝配色的**大圆角软陶长栏（`make_rounded_box(size, min(size.x, size.y) * 0.45, 3)`）+ 圆润木榫立柱**；`NarrowBridge` 侧边警示线改为柔和暖杏橘圆润压边条。
- **云朵跳板与积木终点门**：
  - `add_side_launch_ramp` 与 `add_sky_platform` 改用圆角面板与雾霭粉蓝（`#86C2E6`）+ 暖奶油白圆边护沿，侧向斜拉杆改为柔和暖米色细圆木杆；
  - `_build_finish_archway` 升级为**圆角积木凯旋拱门**：双侧圆润奶油薄荷立柱 + 大圆角暖金绿横梁。
- **固定底座极简化（`MaterialLibrary.attach_anchored_flange_base`）**：
  - 严格保留 `target.set_meta("is_anchored_fixed", true)` 与 `AnchoredFlangeBase` 子节点幂等替换契约；
  - **彻底删除**黑黄警示底板、深灰铸铁方片、4 颗金属六角螺栓与 `"FIXED"` 标签，替换为单一干净的**温润暖陶灰圆角软垫底座（`make_chamfered_cylinder` / `make_rounded_box`）**。

### 2.3 全实体造型重塑、萌感点缀与单面陶印
- **单面柔和“木刻/陶印”标签（`MaterialLibrary.attach_weight_labels`）**：
  - 保留 `target.set_meta("weight_label", weight_text)` 与 `WeightLabelFront` 幂等清理契约；
  - **不再生成顶面重复标签 `WeightLabelTop`**；正面 `WeightLabelFront` 取消粗黑描边（`outline_size = 2`，描边色取柔和半透同色系微衬底，主字色取温暖深木棕 `#5A3E2B` 或柔和暖奶白 `#FAF2E4`，透明度 `0.86`），字号适度收敛约 `18%`，呈现自然压印在木块或软陶上的精致小字。
- **纯粹木艺/彩绘器物类（无五官）**：
  - `CrateObstacle`：主体采用 `make_rounded_box(box_size, 0.14, 3)`；`500g` 轻箱为温暖杏仁浅木色，`2kg` 重箱为醇厚胡桃可可色，四角点缀圆润暖铜软陶包边条（不再刺出尖锐黑铁棱角）；
  - `WoodenPin`：圆周分段提升至 `24` 段，底部改用圆角倒角柱过渡，配柔和珊瑚红漆环；
  - `ExplosiveBarrel`：桶身采用 `make_chamfered_cylinder(0.52, 0.52, 1.25, 0.10, 24)` 配柔和珊瑚白条纹贴图与圆润陶铁箍圈（`TorusMesh`），引爆后切换为哑光深暖炭灰圆桶；
  - `PinballBumper`：删除顶面 `"FIXED"` 大字，中心柱改为圆顶奶油白软陶蘑菇头，外圈环绕饱满蜜桃粉高弹软胶圆环；
  - `SpringPad`：删除顶面粗黑 `"▲▲"` 字，改为圆角鹅黄软胶圆饼垫 + 内嵌柔和奶油白圆角浮雕V形标 + 圆润哑光弹簧圈；
  - `BoostPad` & `SlimeZone` & `AerialBonusRing`：`BoostPad` 改为薄荷绿圆角软垫配圆头胶囊箭头；`SlimeZone` 改为 `make_pebble_pad` 有机圆润果冻水洼；`AerialBonusRing` 改为暖阳金与薄荷绿双层圆润甜圈环，支架改为温润浅木圆杆。
- **极简萌感生命体类（配手作软陶豆豆眼）**：
  - `BouncerSlime`（`3kg`）：水润薄荷绿半透果冻球冠 + 暖亮果核 + 内部悬浮软陶豆豆眼与蜜桃腮红；
  - `ShieldBrute`（`20kg`）：将原 `8` 段生硬八棱柱重构为 `28` 段**圆滚滚深陶灰不倒翁重锤怪**（圆润宽底圆肚 + 圆弧肩颈 + 顶部厚实圆环提手），正面胸腹处镶嵌一对呆萌沉稳的豆豆眼；
  - `AerialBlocker`：珊瑚橘圆润软气球（`250g`）与大圆角深陶灰磁浮块（`12kg`）正面均点缀小巧豆豆眼，下方磁浮环改为柔和粉蓝柔光圆环。
- **主角球与微风飘带**：
  - `PlayerBall3D`：温润釉面陶瓷蓝灰球体配柔和暖金赤道细环；随动推力环（`_hud_ring_root`）中的生硬三棱柱与方块喷气条升级为**圆润胶囊小箭头 + 3 朵圆滚滚的棉花白小云团（`SphereMesh` Puffs）**；球上方标重微缩为柔和奶白无黑框小字；
  - `WindZone`：移除硬边方盒条与尖锐三棱柱，改用柔和低透明度的**胶囊流线云丝（`CapsuleMesh`）**与圆润柔和风向小圆锥，呈现绘本微风拂面感。

---

## 3. 模块三：温暖绘本羊皮纸 UI 与零回归测试验证

### 3.1 全局绘本手账卡片主题（`UiTheme`）
- **配色与圆角体系**：
  - 面板主样式默认升级为**温暖奶油羊皮纸底色** `Color(0.98, 0.95, 0.89, 0.93)`，搭配温润浅胡桃木边框 `Color(0.76, 0.63, 0.49, 0.90)`，全局默认圆角提升至 `18px`，并赋予柔和暖棕底部微投影（`shadow_color = Color(0.28, 0.20, 0.12, 0.14), shadow_size = 6, shadow_offset = Vector2(0, 3)`）；
  - 在 `UiTheme.build_theme()` 中统一注册 `Button`（常态暖杏白 `#F5E9D4`、悬停浅蜜桃奶油 `#FFF6E6`、按下暖沙色 `#E8D6B9`，圆角 `14px`，深可可棕字体 `#4A3525`）、`LineEdit`（圆角内凹米白输入槽）与 `ProgressBar`（暖沙圆角底槽 + 鼠尾草薄荷绿 `#68C7A3` 圆角填充条）样式。

### 3.2 HUD、三选一强化卡与结算单重构（`HudOverlay` / `UpgradeDraftPanel` / `RunSummaryPanel`）
- **`HudOverlay`**：
  - 顶栏主状态卡、右上种子胶囊牌、左下构筑提示卡、右下时速动量卡全面换用温暖奶油手账卡面；
  - 字体颜色由荧光青/亮白切换为高可读性的**深烘焙可可棕（`#463222`）**、**森林鼠尾草绿（`#2E8B6E`，时速高亮）**、**暖琥珀橘（`#C97A2B`，过载乘区）**与**柔和珊瑚红（`#D95B43`，倒计时预警与坠崖提示）**；左右推力徽章在激活态变为温润薄荷绿胶囊灯牌。
- **`UpgradeDraftPanel` & `RunSummaryPanel`**：
  - 模态背景遮罩改为温暖柔和的半透焦糖茶色 `Color(0.18, 0.13, 0.09, 0.58)`；
  - 三选一强化卡片采用绘本手作藏品卡设计（奶油白卡面 `20px` 圆角，普通卡配亚麻暖灰棕边 `#A8957E`、稀有卡配雾霭晴空蓝边 `#5BA4CF`、传奇卡配暖阳琥珀金边 `#E59A38`，选中卡片亮起暖奶油高光并加粗描边）；
  - 结算面板采用同款大圆角手账总结卡，按钮与自定义种子输入框保持圆润温暖手感。

### 3.3 物理零扰动与自动化测试保障
- **物理与确定性隔离**：所有实体的 `CollisionShape3D`、刚体 `mass`、`PhysicsMaterial`、坡道倾角 `-11°`、`TrackGenerator3D` 随机种子流及 `RunState` 计分逻辑**零修改**。
- **单元测试覆盖**：
  1. 新增 `ClayMeshBuilder` 测试用例（挂载至 `tests/test_core_stats.gd`），验证圆角盒、倒角柱、鹅卵石软垫及豆豆眼节点在 Headless 与非 Headless 下的安全行为与参数边界；
  2. 确保全部 6 个测试套件（`test_core_stats.gd`、`test_synergy_and_upgrades.gd`、`test_ball_and_gravity.gd`、`test_entities.gd`、`test_track_generator.gd`、`test_game_loop.gd`）通过 `./scripts/test.sh` 全绿验证；
  3. 重新导出 `web/` HTML5 包以同步最新绘本风视觉资产与代码。
