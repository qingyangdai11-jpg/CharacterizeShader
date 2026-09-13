# 二次元角色展示项目 Workflow

适用工程：`chashader/CS15c`；Unity 2020.3.48f1c1，Built-in 渲染管线，主场景 `Assets/CS15/CS15.unity`。

本文按当前工程资源、脚本、Animator 配置以及本次 Shader 接入记录还原制作流程，可用于项目报告、作品集和答辩。工程不能证明的建模软件操作、手工权重修改和关键帧编辑历史，不写成已经完成的事实；相应内容标记为检查步骤或后续优化。

## 1. 整体流程与系统分工

**带骨骼模型导入 → 材质槽与贴图绑定 → Avatar/蒙皮检查 → 身体动画适配 → 从 FBX 提取面部动画并叠加播放 → 裙摆与头发动态骨骼 → 防穿模约束 → 灯光与 Toon Shader → 镜头交互 → 服装及动作切换 → 整体验证。**

| 模块 | 项目采用的方法 | 解决的问题 |
|---|---|---|
| 角色导入 | FBX、SkinnedMeshRenderer、Humanoid Avatar、Prefab | 保留模型、骨骼、材质槽及动画驱动关系 |
| 材质贴图 | 按身体/服装/头发/眼睛等材质槽分配，保留 UV 与贴图变换 | 让不同部位具有不同外观 |
| 身体动作 | Humanoid 重定向、Animator 状态机、整数参数 | 复用动作并通过 UI 切换 |
| 面部表情 | 从 FBX 提取 AnimationClip，通过 Emotion 层播放 | 身体运动与面部表情同时播放 |
| 二级运动 | Dynamic Bone 粒子链、Verlet 积分、长度与姿态约束 | 头发和裙摆产生跟随、滞后与回弹 |
| 动态防穿模 | 骨骼绑定的球/胶囊碰撞体与粒子投影修正 | 减少裙摆进入腿部 |
| 角色渲染 | 半兰伯特分色、RGB Ramp、遮罩高光、环境反射、描边 | 二次元材质表现 |
| 展示交互 | MouseOrbit、Swapper、UI 按钮事件 | 旋转观察、缩放、换装与动作控制 |

## 2. 角色模型导入：建立可驱动的角色资产

### 2.1 导入带骨骼的 FBX

项目使用已有的带骨骼角色模型，例如 `Assets/茜特菈莉01.fbx`、`Assets/茜特菈莉02.fbx`，并在 `Assets/CS15/Char/Prefabs` 中保存角色 Prefab。

导入后的角色由骨架层级和多个 SkinnedMeshRenderer 组成，身体、脸部、头发、服装及饰品保留独立部件或材质槽。这样可以分别调整材质，也便于给头发、裙摆选择动态骨骼根节点。

### 2.2 保留蒙皮、法线与 BlendShape

以茜特菈莉 01 的导入配置为例：

- `importBlendShapes: 1`：导入面部形态键，为后续表情提供基础。
- `animationType: 3`：采用 Humanoid 动画类型。
- `avatarSetup: 1`：从当前模型建立 Avatar。
- 配置允许未明确指定时自动生成 Avatar 映射；当前文件不包含手工映射列表，因此不能将它描述为“已经逐根手工绑定”。

需要检查模型在 Unity 中的尺寸、朝向、法线和切线。特别是法线与切线不仅影响基础光照，也会影响头发高光方向和眼睛视差。

### 2.3 保存 Prefab

将模型实例、材质引用和组件配置保存为 Prefab，使不同服装版本可以独立维护并被场景复用。

**知识点：** FBX 资产导入、Prefab 复用、局部/世界坐标、SkinnedMeshRenderer、UV、顶点法线、切线、BlendShape。

## 3. 材质与贴图：先恢复对应关系，再调整渲染风格

### 3.1 按原材质槽分配贴图

模型材质通过 `.mat` 资产引用贴图；FBX 的 `externalObjects` 记录了部分原材质名称到外部材质的映射。

本项目保持身体、衣服、皮肤、头发和眼睛原有贴图对应关系，不把所有 Renderer 替换为同一个材质。一个 Renderer 也可能有多个子网格，必须逐个材质槽匹配。

本次 Shader 接入迁移了 **127 个角色材质**，并按原 Prefab 的 Renderer 和材质槽恢复了主场景 **23 个 Debugger 材质覆盖**。这些数字来自 `ShaderReview/migration.json`，属于本次接入工作。

### 3.2 贴图承担不同数据职责

| 属性 | 当前 Shader 的读取方式 | 作用 |
|---|---|---|
| `_MainTex` | RGB 基础色，Alpha 可用于裁剪 | 角色颜色与图案 |
| `_BumpMap` | 切线空间法线 | 衣褶、局部凹凸、眼球法线 |
| `_AOMap` | R 通道 | 遮蔽区域的明暗控制 |
| `_LightMap` | R 阴影偏移，G 遮蔽 | 可选角色专用光照控制图 |
| `_DiffuseRamp` | RGB 三个染色权重 | 三层风格化阴影颜色 |
| `_SpecMap` | R 高光遮罩，A 光滑度 | 限制高光区域和控制高光宽度 |
| `_EnvMap` | Cubemap | 环境反射 |
| `_TattooTex` | RGBA | 可选纹身叠加 |
| `_DecalMap` | RGB | 眼部固定高光贴花 |
| `_EmissionMap` | RGB 乘发光颜色 | 可选自发光 |

这里的 `_LightMap` 是角色控制贴图，不等同于 Unity 烘焙场景 Lightmap。不同模型的控制图通道定义可能不同，不能仅凭文件名认为它们可以互换。

迁移兼容了旧材质中的 `_BaseMap → _MainTex`、`_NormalMap → _BumpMap`，同时保留贴图 Tiling/Offset。视频材质中遗留的灰色 `_Color` 原先未被教程着色代码使用，迁移时恢复白色，避免重复压暗基础色。

### 3.3 可选贴图不需要全部填满

没有使用环境反射、纹身或发光效果时，可以让相应槽位为空，同时关闭对应强度。空纹身图的混合强度保持为 0，避免默认黑色覆盖原底色。

导入检查原则：颜色图按颜色数据处理，法线图设为 Normal map，遮罩类数据图检查是否应关闭 sRGB；Ramp 检查 Clamp 和 Mipmap 设置。本次没有统一重写所有共享贴图的导入配置。

**知识点：** 子网格与材质槽、纹理采样、通道打包、法线贴图、颜色空间、UV 变换、资源 GUID 引用。

## 4. 骨骼调整：保证 Avatar、蒙皮和附属骨骼各司其职

### 4.1 身体骨骼使用 Humanoid 重定向

通过 Humanoid Avatar 建立髋部、脊柱、头部、四肢等标准人体关系，使已有动作可以适配不同角色。

需要依次检查 Avatar 是否有效、人体骨骼是否映射正确、参考姿态是否合理，再播放待机和跑步测试。这里的“骨骼调整”首先是映射、姿态与层级检查，并不表示重新生成骨架。

### 4.2 服装必须与蒙皮骨骼保持一致

SkinnedMeshRenderer 通过骨骼矩阵、Bind Pose 和顶点权重驱动顶点。概念上可写为：

```text
变形后顶点 ≈ Σ（骨骼权重 × 当前骨骼变换 × 对应 Bind Pose × 原顶点）
```

若出现整片服装拉长、扭曲或翻转，应先检查 `bones`、`rootBone`、绑定姿态和骨架缩放，而不是靠 Shader 修复。

项目中能确认的是已有蒙皮模型、Avatar 与动态骨骼配置；没有足够记录证明进行了哪些 Blender/Maya 权重绘制或具体顶点修改。如果报告需要加入这些制作经历，应补充实际操作记录。

### 4.3 附属骨骼交给 Dynamic Bone

头发和裙子的骨骼链保留在人体骨架之外，由 Dynamic Bone 在身体动画之后补充运动。主要身体骨骼由 Animator 控制，附属骨骼在动画姿态基础上产生跟随效果，减少同一条骨骼链被多个系统相互覆盖。

**知识点：** 骨骼层级、Humanoid Avatar、动画重定向、线性蒙皮、Bind Pose、顶点权重、更新顺序。

## 5. 身体动画：裁剪动作、配置状态机、用参数驱动

### 5.1 导入和裁剪动画片段

动作资源位于 `Assets/CS15/Char/Animations`。工程包含待机、跑步、转向、跳跃、姿势和告别等 FBX 动画。

导入配置可见具体片段裁剪，例如：

- `Anim@Run.fbx`：帧区间 201–224，开启循环。
- `Anim@Idle_A.fbx`：帧区间 1101–1135，开启循环。

这体现了从源动画中选取有效片段、为连续动作配置循环的流程。不能仅根据这些设置声称重新制作了动作关键帧。

### 5.2 Animator 状态机

主要控制器为 `Animator_Reisa.controller`，身体动作由整数参数 `animation` 驱动。UIRoot 的按钮通过 `SetInt("animation,编号")` 调用 Swapper。

| 编号 | 对应状态 | 动作含义 |
|---|---|---|
| 1 | Idle_A | 待机 A |
| 2 | Idle_B | 待机 B |
| 3 | IdleC | 待机 C |
| 4 | Angpose | 姿势动作 |
| 5 | Run | 跑步 |
| 6 | Run_L | 左向跑步 |
| 7 | Run_R | 右向跑步 |
| 8 | Jump | 跳跃 |
| 9 | CuteA | 可爱姿势 |
| 10 | Bye | 告别 |
| 11 | Rei | 行礼 |

状态机使用参数条件控制进入与退出，并设置过渡时间。多个进入动作的过渡为 0.1，但并非所有过渡都相同。过渡混合可以避免动作切换瞬间直接跳到另一姿态。

控制器还保留其他状态与参数；以上表格对应已确认的基础按钮入口，不将所有残留状态都视为可用功能。

### 5.3 Root Motion 与动作检查

展示系统通常需要角色在固定位置播放动作，但当前场景中 `Apply Root Motion` 存在不同设置，不能统一表述为全部关闭。应按角色 Animator 分别检查位移是否符合展示需求。

动作调整检查顺序是：动作片段范围 → 循环接缝 → Avatar 适配 → 播放速度与过渡 → 根运动 → 极端姿态下的服装交叠。

**知识点：** AnimationClip、帧范围、循环动画、有限状态机、参数条件、过渡混合、Root Motion。

## 6. 表情：从 FBX 提取面部动画，通过 Animator 叠加播放

### 6.1 实际制作流程：使用 FBX 中已有的面部 Animation

本项目的表情制作流程是：从 FBX 中导出/提取已有的面部 AnimationClip，保存为独立动画资源，再放入 Animator 播放。项目中的源资源包括 `Emotions/茜特菈莉_面部动画.fbx`，独立面部动画为 `Emotions/Face_Smile.anim`。

操作流程可表述为：

1. 将包含面部动画的 FBX 导入 Unity，确认其中的面部动画片段可以读取。
2. 从 FBX 提取面部 AnimationClip，保存为可独立使用的 `.anim` 资源。
3. 将 `Face_Smile.anim` 配置到 Animator 的 `Face_Smile` 状态。
4. 在独立 Emotion 层播放该动画，与 Base Layer 的待机、跑步等身体动作同时运行。
5. 检查角色脸部是否随动画正确变化，并确认身体动作没有被面部片段覆盖。

**制作时直接使用的是 AnimationClip；BlendShape 是该片段内部驱动的面部属性。** 两者属于同一实现的不同层次：动画资源负责记录和播放随时间变化的数据，BlendShape 负责根据这些数据改变面部网格。这个流程不应写成“手动编写脚本逐帧控制 BlendShape 权重”。

### 6.2 在 Emotion 层播放导出的面部动画

`Animator_Reisa.controller` 中设置独立 `Emotion` 层：

- 混合模式为 Override。
- 权重为 1。
- 当前默认状态为 `Face_Smile`，其 Motion 引用导出的 `Face_Smile.anim`。
- `Face_Smile.anim` 开启循环。
- 当前层没有 Avatar Mask，也没有一套已连接的多表情切换网络。

身体动作由 Base Layer 播放，面部动画由 Emotion 层播放。当前面部片段只记录脸部相关属性，因此可以在身体动作继续运行时叠加表情。这里使用的是动画分层与属性分离，不能描述为已经通过 Avatar Mask 隔离表情。

控制器虽然存在 `smile`、`emo1` 等 Trigger 参数，当前 Emotion 层主要实现的是默认循环播放微笑动画，不代表所有 Trigger 都已经接通。

### 6.3 底层原理：动画曲线驱动 BlendShape

检查导出的 `Face_Smile.anim` 可以看到，它记录了以下属性曲线，目标路径为 `Face`，组件为 SkinnedMeshRenderer：

```text
blendShape.Mouth_Smile01
blendShape.Eye_WinkA_L
blendShape.Eye_WinkA_R
blendShape.A
```

Animator 播放这个片段时，会对曲线进行求值，把对应时刻的数值写入面部 BlendShape 权重，产生微笑、眼部和嘴部变化。因此完整的数据关系是：

```text
FBX 中的面部动画
  → 提取为 Face_Smile.anim（AnimationClip）
  → Animator 的 Emotion 层播放
  → 动画曲线更新 Face 的 BlendShape 权重
  → 面部网格产生表情变化
```

BlendShape 的原理是按权重混合预先制作的顶点形变。本项目使用了源动画已经包含的权重曲线；这并不表示在本次 Unity 制作中重新创建了这些形态键或手工重做了全部面部关键帧。

### 6.4 验证导出动画的绑定

`InspectClip.cs` 使用 `AssetDatabase.LoadAllAssetsAtPath` 读取 FBX 子资源，再通过 `AnimationUtility.GetCurveBindings` 查看动画曲线的目标路径、类型与属性名。检查日志确认源 FBX 的面部动画绑定到了 `Face` 的上述四个 BlendShape。

这个脚本用于检查动画内容，不是每帧控制表情的运行时脚本，也不是面部动画导出器。

如果导出的 AnimationClip 播放了却没有表情变化，优先检查角色的 Renderer 路径和 BlendShape 名称是否与片段绑定一致；Humanoid 重定向不会自动替换这些字符串绑定。

**报告中的推荐表述：**

> 我从 FBX 中提取面部 AnimationClip，并在 Animator 中建立独立的 Emotion 层播放，使表情与身体动作同时运行。该动画内部通过已有的 BlendShape 权重曲线驱动嘴部和眼部变化。

**知识点：** FBX 动画子资源、AnimationClip 提取与复用、Animator 分层播放、Override 混合、属性曲线绑定、BlendShape 底层形变。

## 7. 裙子与头发摆动：DynamicBone.cs 的实现方法

### 7.1 将骨骼链转换成粒子链

Dynamic Bone 从 `m_Root` 向下遍历骨骼，将节点记录为粒子，保存父节点索引、当前位置、上一帧位置、初始局部姿态和链长度。

根粒子跟随动画骨骼，后续粒子进行模拟。`EndLength` 或 `EndOffset` 可以生成虚拟末端，`Exclusions` 用于排除不希望参与模拟的节点。

### 7.2 Verlet 积分产生滞后

`UpdateParticles1` 使用当前位置与上一帧位置之差估计运动：

```csharp
Vector3 v = p.m_Position - p.m_PrevPosition;
Vector3 rmove = m_ObjectMove * p.m_Inert;
p.m_PrevPosition = p.m_Position + rmove;
p.m_Position += v * (1 - damping) + force + rmove;
```

角色移动后，骨链末端不会立刻追上根节点，而是结合上一帧运动、阻尼与外力继续移动，因此形成头发拖尾、裙摆晃动和停止后的回弹。

这是一套粒子位置与约束求解，不是给每根骨骼添加 Rigidbody 和 Joint，也不是完整的布料网格仿真。

### 7.3 用约束保持骨链形状

`UpdateParticles2` 依次处理弹性回拉、刚性限制、碰撞、可选冻结轴和骨段长度约束。最后 `ApplyParticlesToTransforms` 使用 `Quaternion.FromToRotation` 将原骨段方向旋转到模拟后的方向，更新实际骨骼。

该组件在 LateUpdate 阶段完成主要模拟与骨骼更新，以当前动画姿态作为参考，再叠加二级运动。

| 参数 | 实际作用 | 调整方向 |
|---|---|---|
| Damping | 削弱历史速度 | 越大越快停止晃动 |
| Elasticity | 拉回参考姿态 | 控制恢复趋势 |
| Stiffness | 限制偏离参考位置的范围 | 保持发束、裙片形状 |
| Inert | 将角色根对象位移带入粒子 | 本实现中越大，根位移跟随通常越强；不能简单理解成越大越飘 |
| Radius | 粒子碰撞半径 | 为裙片和身体保持间隔 |
| Friction | 碰撞后增加的阻尼 | 降低接触位置的滑动 |
| Gravity / Force | 重力与额外力 | 控制下垂或持续偏移 |
| Distribution 曲线 | 沿链长度调整参数 | 可实现根部稳、末端柔的变化 |

裙摆一般需要保持较强形状约束并与腿部碰撞；头发则根据发束长度调节回弹、阻尼与头肩碰撞。当前修复脚本针对裙子，不能把裙子的参数直接写成全部头发的实际配置。

**知识点：** Verlet 积分、位置约束、父子粒子链、阻尼、弹性、骨段长度保持、四元数方向对齐、二级运动。

## 8. 动作防皮肤穿模：碰撞体跟随身体，裙摆粒子受约束

### 8.1 当前已经实现的办法

`FixCitlaliColliders.cs` 查找场景对象 `茜特菈莉02 (1)`，在 Armature 中递归查找大小腿骨骼。腿部的 DynamicBoneCollider 随腿骨运动，为裙摆提供动态障碍物。

脚本对名称包含 `Skirt` 的 Dynamic Bone 根节点进行批量配置，并把右大腿、右小腿碰撞体加入其 `m_Colliders` 列表。它不会检查或修复全部身体网格，也不保证任何极端动作都完全无穿模。

该脚本位于 Editor 目录：编辑器重载后通过 `InitializeOnLoad` 和 `delayCall` 尝试配置，也提供 `Tools/修复茜特菈莉02裙子穿模 (Fix Skirt Collision)` 菜单。它使用 Undo/SetDirty 并将场景标记为已修改，需要保存场景才能持久化配置；它不是构建后每帧运行的修复器，且依赖指定对象名称与查找结果。

脚本当前写入的裙摆参数为：

| 参数 | 数值 |
|---|---:|
| 粒子 Radius | 0.00055 |
| Inert | 0.15 |
| Damping | 0.25 |
| Elasticity | 0.55 |
| Stiffness | 0.65 |

这些数值依赖当前骨架缩放，不能直接当成通用世界尺寸。碰撞体半径代码会乘以 `abs(transform.lossyScale.x)`，因此应以场景实际尺寸和 Gizmo 为准，而不是照抄注释中的厘米换算。

### 8.2 球/胶囊碰撞的数学方法

`DynamicBoneCollider.cs` 提供 Sphere/Capsule，以及 Outside/Inside 两类约束。裙摆使用 Outside，使粒子保持在身体碰撞体外部。

对于球形约束：

```text
安全距离 R = 身体碰撞半径 + 裙摆粒子半径
若粒子与球心距离 d < R，则沿球心到粒子的方向推至 R
```

胶囊约束先判断粒子相对轴线的位置，分别处理端部球面与中间柱体，再把侵入粒子推到外侧。这属于位置投影式的穿透修正。

代码会在 `Height / 2 - Radius <= 0` 时使用球形分支。因此，当前右大腿参数 `Radius=0.003、Height=0.004` 实际得到球形约束；不能笼统写成所有腿部组件都是胶囊。

### 8.3 为什么还需要动作与蒙皮检查

Dynamic Bone 约束的是骨骼粒子，不是裙子每一个三角形。骨链间距、蒙皮权重和快速动作仍可能造成裙面穿入腿部。

若仍有问题，后续按顺序检查：碰撞体覆盖范围 → 粒子半径 → 骨链间隙 → 约束参数 → 动作极端姿态 → 蒙皮权重。修改动作关键帧、隐藏衣服下的身体面或增加辅助骨骼都属于可选优化，当前工程记录不足以证明这些工作已经实施。

**知识点：** 局部/世界尺度、球与胶囊距离计算、碰撞投影、粒子近似与网格表面的差别、动态穿透修正。

## 9. 打光：先建立真实光照，再调 Shader 风格

角色使用 Directional Light 提供主要照明，Shader 读取 `_LightColor0` 和世界空间光照方向。方向光旋转决定明暗分界和高光位置，Intensity 控制强度。

项目调试中出现过“背景很亮但角色近乎黑色”：当时截图显示主光 Intensity 为 0。旧 Unlit 材质不依赖灯光，新 Toon Shader 会计算直接光，所以更换 Shader 后这个设置立即暴露出来。

实际调节顺序：

1. 恢复主光强度，先以 1 为起点观察。
2. 调整方向，让面部能获得合适的受光。
3. 再调阴影阈值和阴影颜色。
4. 最后增加少量环境光、边缘光或 Cubemap 反射。

环境光通过 `ShadeSH9` 读取球谐光照近似；材质 Cubemap 则独立负责反射。背景可使用另一套渲染方式，因此背景亮度不能直接代表角色受光是否正确。

当前 Shader 已提供投影与受影代码，但灯光使用 No Shadows 时不会产生实时阴影。不能仅凭存在 ShadowCaster Pass 就声称场景已经开启阴影。

**知识点：** 直接光、环境光、球谐光照、方向光、光照衰减、阴影与材质分色的区别。

## 10. 角色 Shader：共享光照结构，按材质类型细分

五类 Shader 共同使用 `ToonCommon.cginc`，通过编译宏选择眼睛、皮肤和头发的特殊处理。使用 ShaderLab 组织渲染 Pass，使用 CG/HLSL 编写顶点和片元计算。

### 10.1 公共基础：TBN 法线变换

将顶点法线 N、切线 T、副切线 B 转到世界空间，读取法线图并用 `UnpackNormal` 解码：

```text
世界法线 = normalize(T × normalTS.x + B × normalTS.y + N × normalTS.z)
```

副切线通过叉积构造，并考虑切线手性和物体镜像缩放。片元阶段重新归一化，减少插值导致的长度误差。

**作用：** 衣褶和局部法线细节可以在不增加模型面数的情况下影响光照。

### 10.2 toon_standard：服装与饰品

**① 半兰伯特与阈值分色**

```text
halfLambert = saturate(dot(N,L) × 0.5 + 0.5 + 可选光照图偏移)
shade = halfLambert × AO × 可选顶点色遮罩
lit = smoothstep(阈值 - 宽度, 阈值 + 宽度, shade)
```

将连续光照压缩为清晰的亮面和暗面。宽度取材质 Softness 与 `fwidth(shade)` 的较大值，用屏幕导数缓和分界锯齿。半兰伯特属于风格化经验模型，不是物理能量守恒模型。

**② RGB 三层 Ramp 染色**

启用 `_UseRamp` 时，分别采样 Ramp 的 R/G/B 通道。每层可以使用独立 Offset，再按 Tint 的 Alpha 控制染色强度：

```text
tint = lerp(白色, Tint1.rgb, RampR × Tint1.a)
     × lerp(白色, Tint2.rgb, RampG × Tint2.a)
     × lerp(白色, Tint3.rgb, RampB × Tint3.a)
```

它把受光量映射成可设计的颜色层，让服装阴影保留暖色、紫色等风格，而不是单纯变黑。当前 Ramp 采用固定纵坐标 0.5 采样，属于三个通道的权重查表。

**③ 遮罩控制的 Blinn–Phong 高光**

```text
H = normalize(L + V)
spec = pow(saturate(dot(N,H)), max(1, 指数 × 光滑度))
```

高光再乘 `_SpecMap.R`、高光颜色、强度以及光照衰减。指数越大，高光通常越集中；高光遮罩可以限制衣服装饰和局部光泽区域。这里没有实现完整金属度/粗糙度 PBR BRDF，不宜描述成完整物理材质。

**④ Cubemap 环境反射与菲涅耳近似**

使用 `reflect(-V,N)` 得到反射方向，绕 Y 轴旋转后采样 Cubemap。粗糙度通过 `roughness × 6` 选择 Mip 级别，较粗糙时读取更模糊的层，再用 `DecodeHDR` 解码。

反射权重采用 `smoothstep` 处理 `1 - saturate(N·V)`，强调掠射角反射。这是可调菲涅耳近似，不是完整 Schlick 方程。

**⑤ 轮廓光与屏幕像素描边**

轮廓光使用 `(1 - saturate(N·V))^power`，叠加少量边缘亮度。

描边另开 Pass，`Cull Front` 绘制扩张后的背面外壳。把法线方向投影到屏幕平面，结合 `_ScreenParams` 和裁剪坐标 w 进行偏移：

```text
clip.xy += 屏幕方向 × 2 × 像素宽度 / 屏幕尺寸 × clip.w
```

因此轮廓宽度按像素控制，随镜头距离变化相对稳定。它是几何外壳描边，不是基于深度/法线图的全屏边缘检测。

### 10.3 toon_nonoutline：保留着色，省去描边

复用普通材质的分色、高光、反射和阴影，只移除描边 Pass。用于眉毛、嘴部、贴身叠片及原 NoOutline 部件，避免眼口位置和重叠几何出现不需要的粗黑边。

**知识点：** 多 Pass 组织、背面剔除、子部件渲染差异。

### 10.4 toon_skin：柔化皮肤受光

先对 `N·L` 使用 Wrap Lighting：

```text
wrappedNdotL = (NdotL + SkinWrap) / (1 + SkinWrap)
```

再进入共同的半兰伯特/Ramp 流程，扩大柔和受光区域，配合暖色阴影和较弱高光，使皮肤比衣物柔和。

纹身通过 Alpha 混合覆盖底色：

```text
base = lerp(base, tattoo.rgb × tattooColor,
            tattoo.a × tattooColor.a × tattooStrength)
```

**知识点：** 包裹式漫反射、色调控制、Alpha 叠加。当前没有基于厚度图或屏幕空间扩散的真实次表面散射，也没有 SDF 人脸阴影；不能将这两项写成已实现。

### 10.5 toon_hair：各向异性带状高光

头发使用 UV 切线框架中的副切线 B 作为发丝方向近似，并用法线偏移调节高光位置：

```text
strand = normalize(B + N × HairShift)
th = dot(strand, H)
anisotropic = pow(sqrt(saturate(1 - th²)), 指数)
spec = lerp(普通高光, anisotropic, HairAnisotropy)
```

`sqrt(1 - th²)` 对应方向夹角的正弦项，使高光沿发束方向表现出各向异性，再由高光图限制具体区域。它属于 Kajiya–Kay 类的方向性高光近似，而不是完整的毛发多重散射模型。

**参数作用：** HairShift 改变高光位置；HairAnisotropy 在普通高光与方向性高光之间混合；SpecShininess 控制集中程度。

发丝方向依赖模型 UV 与切线。如果 UV 方向不一致，高光也会不一致；此时可降低各向异性，或在建模端统一方向。Dynamic Bone 控制头发几何摆动，toon_hair 控制头发外观，二者是不同系统。

### 10.6 toon_eye：虹膜深度感与角膜高光

**① 凹面虹膜光照**：将切线法线的 XY 分量反向，用于虹膜漫反射；保留原法线计算角膜反射，从而区分内凹虹膜与外凸眼球的观感。

**② 切线空间视差**：把视线投影到 T/B/N，依据视线倾斜程度偏移虹膜基础贴图 UV。使用中心区域深度权重、分母下限和偏移截断，避免侧视时偏移失控。

```text
offset ≈ viewTS.xy / max(abs(viewTS.z), 0.25)
       × Parallax × 中心深度权重
```

**③ 高光层**：结合普通高光、Cubemap 反射和不随虹膜偏移的 Decal 高光，使眼睛产生湿润感。当前是单材质中的光照与采样近似，不是真实折射追踪。

眼睛不绘制描边。视频局部 UV 的眼材质采用较保守的 -0.025 视差；茜特菈莉图集眼材质默认关闭视差，防止偏移后采样到相邻图块。不能给所有眼睛统一开启视差。

### 10.7 实时阴影、附加光和透明裁剪

普通、皮肤、头发包含 ForwardBase、ForwardAdd、Outline、ShadowCaster 四个 Pass；眼睛和无描边材质包含三个。

- ForwardBase：主光、环境光及材质效果。
- ForwardAdd：`Blend One One` 叠加附加实时光，不重复加入环境反射。
- ShadowCaster：输出阴影所需深度。
- Alpha Clip：在主光、附加光、描边和投影中统一采用透明度阈值。

Alpha Clip 是硬边裁剪，不是连续半透明，不能直接替代玻璃或薄纱材质。着色器还使用 Unity 雾效宏，并避免在眼睛内部重复做视频末尾的 Gamma/ACES 变换。

## 11. 场景旋转与观察：MouseOrbit.cs

该脚本挂在相机上，区分三个对象：`targetFocus` 为观察中心，`targetObj` 为当前展示角色，`mainLight` 为可旋转主光。

### 11.1 相机轨道运动

在 LateUpdate 中读取鼠标增量，积累水平角 x 和垂直角 y，再计算：

```csharp
Quaternion rotation = Quaternion.Euler(y, x, 0);
Vector3 position = rotation * new Vector3(0, height, -cur_distance)
                 + targetFocus.position;
```

由旋转后的局部偏移确定相机世界位置，实现围绕角色观察。`ClampAngle` 限制俯仰角，滚轮修改距离并通过 `Mathf.Clamp` 限定缩放范围。

### 11.2 角色旋转与主光旋转

| 输入 | 当前代码行为 |
|---|---|
| 默认左键拖动 | 环绕相机 |
| J | 切换 `EnableDragObject`，开启后拖动可旋转角色 |
| K | 切换 `EnableRotateLight`；在对象拖动模式下，将旋转目标改成主光 |
| 滚轮 | 调整观察距离 |
| 上/下方向键 | 调整观察高度 |

角色旋转使用 `targetObj.transform.Rotate(Vector3.up, ..., Space.World)`，改变模型自身朝向；相机环绕则改变相机位置。两者都能观察不同角度，但空间关系不同。

脚本通过 `current += (target-current) × deltaTime × speed` 平滑速度，实现拖拽缓动。它不是严格帧率无关的阻尼器，快速运动表现仍应在目标帧率检查。

`Reset()` 还会收集 Renderer 包围盒和普通 Collider；存在 Collider 时可用射线估计观察距离。该逻辑服务于镜头，不负责裙子防穿模，也不等同于 DynamicBoneCollider。

**知识点：** 四元数、轨道相机、坐标变换、世界轴旋转、插值缓动、角度限制、包围盒和射线检测。

## 12. 切换服装与动作：Swapper.cs

### 12.1 换装通过切换完整对象实现

`character[]` 存放不同角色/服装版本，`animators[]` 存放其 Animator。`Awake()` 关闭所有版本，再启用第一个。

点击右上角由 `OnGUI` 绘制的按钮后：

1. 保存当前角色旋转。
2. 关闭当前对象，递增索引并对数组长度取模。
3. 启用下一套角色，并恢复之前的旋转。
4. 重新发送当前动作编号。
5. 更新相机 MouseOrbit 的 `targetObj`。

因此，当前“换服装”是多套预配置角色对象的显隐切换，没有实现运行时拆装服装网格、重新绑定骨骼或装备插槽系统。

### 12.2 UI 通过字符串参数切换动作

例如按钮发送 `animation,5`：

```text
按钮 OnClick
  → Swapper.SetInt("animation,5")
  → 拆分为参数名 animation 和整数 5
  → 向 animators[] 中的 Animator 写入 SetInteger
  → 状态机根据条件进入 Run
```

脚本保存 `cur_animid`，使换装后继续使用同一动作编号。它不保存 `normalizedTime`，因此只能说保持动作选择，不能保证逐帧无缝延续播放进度。

`SetFloat`、`SetBool`、`SetTrigger` 提供其他参数入口，是否产生效果取决于 Animator 中是否配置对应参数和连接关系。

切换时当前代码没有重新调用 MouseOrbit.Reset，也没有刷新所有镜头碰撞缓存；如果后续增加体型差异明显的角色，可将刷新观察中心、包围盒和缓存作为优化。

**知识点：** 对象显隐切换、数组与取模、UI 事件绑定、参数解析、Animator 参数驱动、状态保存。

## 13. 联调与验证记录

| 检查项 | 本项目的检查方式 |
|---|---|
| 导入/蒙皮 | 比较原模型、Prefab 和播放动画后的姿态，分离骨架问题与着色问题 |
| 材质 | 核对材质槽、贴图与 Shader GUID；检查可选功能强度 |
| 身体动作 | 逐项点击动作按钮，观察过渡、位移和极端姿态 |
| 表情 | 检查 FBX 提取的 AnimationClip 及绑定；观察 Emotion 层与身体动作同时播放 |
| 动态骨骼 | 跑步、跳跃、转向和停止后观察回弹与腿裙接触 |
| 灯光 | 先检查主光强度和方向，再调整 Ramp、反射与边缘光 |
| Shader | 同版本 Unity / D3D11 编译与实际模型渲染 |
| 换装与镜头 | 检查朝向保持、动作编号保持和相机目标更新 |

本次已完成的 Shader 验证：五类 Shader 均受支持，所测 30 个主光、附加光与投影变体编译错误为 0；莱莎和茜特菈莉 01 的独立 Prefab 渲染已检查。不能将其扩大表述为所有平台、所有变体和所有动作均已通过测试。

茜特菈莉 02 曾在无动画的独立 Prefab 测试中发生骨骼变形，改用内置 Unlit 后仍存在；用户后续场景截图显示了正常展示姿态，因此这个独立测试现象也不能直接代表当前动画运行一定异常。

## 14. 可直接用于项目介绍的简述

> 本项目在 Unity 内置渲染管线中完成了二次元角色的导入、材质配置、动画驱动与交互展示。角色使用带骨骼 FBX 和 Humanoid Avatar 适配身体动作，通过 Animator 状态机与整数参数切换待机、跑步、跳跃等动作，并从 FBX 提取面部 AnimationClip，通过独立 Emotion 层与身体动作叠加播放；片段内部由已有的 BlendShape 权重曲线驱动表情。裙摆和头发使用 Dynamic Bone 的 Verlet 粒子链与姿态、长度约束产生二级运动，裙摆结合腿部碰撞体减少动态穿模。渲染部分按服装、无描边部件、皮肤、头发和眼睛拆分五类 Toon Shader，综合运用半兰伯特分色、RGB Ramp 染色、遮罩高光、各向异性头发高光、眼睛视差、环境反射及屏幕像素描边。展示交互由 MouseOrbit 实现相机环绕和角色旋转，由 Swapper 切换整套服装对象并保留当前动作选择。

## 15. 源码与资源索引

以下路径均相对于 `CS15c/Assets/`：

| 文件/目录 | 核对内容 |
|---|---|
| `茜特菈莉01.fbx.meta`、`茜特菈莉02.fbx.meta` | 模型导入、Avatar、BlendShape、材质映射 |
| `CS15/Char/Prefabs/` | 角色层级和服装版本 |
| `CS15/Char/Animations/Animator_Reisa.controller` | 身体状态机、animation 参数、Emotion 层 |
| `CS15/Char/Animations/Emotions/茜特菈莉_面部动画.fbx` | 源面部动画资源 |
| `CS15/Char/Animations/Emotions/Face_Smile.anim` | 从 FBX 提取的面部 AnimationClip，内部记录四条 BlendShape 曲线 |
| `Editor/InspectClip.cs`、`clip_inspect_log.txt` | 面部动画绑定检查 |
| `Editor/FixCitlaliColliders.cs` | 腿部碰撞体与裙摆参数修复 |
| `DynamicBone/Scripts/DynamicBone.cs` | 粒子建立、Verlet、约束和骨骼更新 |
| `DynamicBone/Scripts/DynamicBoneCollider.cs` | 球/胶囊碰撞求解 |
| `CS15/Shaders/ToonCommon.cginc` | 五类 Shader 的共同计算 |
| `CS15/Shaders/toon_*.shader` | 材质属性、编译宏和渲染 Pass |
| `CS15/Scripts/MouseOrbit.cs` | 镜头与角色/灯光旋转 |
| `CS15/Scripts/Swapper.cs` | 换装和动作参数入口 |
| `CS15/UI/UIRoot.prefab` | 动作按钮回调与编号 |
| `Editor/ToonShaderValidation.cs` | Shader 编译和隔离渲染验证 |

工作区 `ShaderReview/Original/` 保存本次接入前的材质与场景备份，`ShaderReview/migration.json` 保存迁移清单，`ShaderReview/shader-validation.txt` 保存编译报告。
