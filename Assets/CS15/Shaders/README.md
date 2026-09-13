# CS15 二次元角色 Shader

适用：Unity 2020.3，Built-in Forward。主场景：`Assets/CS15/CS15.unity`。
Shader 菜单：`CS15/toon_eye`、`CS15/toon_hair`、`CS15/toon_nonoutline`、`CS15/toon_skin`、`CS15/toon_standard`。

参考工作区《26 二次元角色Shader.mp4》的基础色/AO/法线/高光拆分、RGB 三层 Ramp 染色、高光遮罩、菲涅耳环境反射和眼睛视差思路；不是逐字复刻视频。
视频中的材质已经保留了对应贴图与参数，本次恢复并迁移到新 Shader。

| Shader | 用途 | 特有处理 |
|---|---|---|
| toon_standard | 服装、饰品、身体与服装混合图集 | 三层染色、高光、环境反射、描边 |
| toon_nonoutline | 眉毛、嘴部、贴身叠片、原 NoOutline 部件 | 不包含描边 Pass |
| toon_skin | 脸部、独立皮肤、脖颈 | 柔化受光方向、暖色阴影、纹身叠加 |
| toon_hair | 头发 | 切线方向各向异性高光，可调偏移和强度 |
| toon_eye | 眼球/虹膜 | 凹面虹膜光照、角膜反射、高光贴花、可选视差，无描边 |

## 已接入内容

- 127 个角色材质已换用对应 Shader，保留各自基础贴图、缩放和偏移。
- 主场景 23 个 Debugger 材质覆盖已依据原 Prefab 的 Renderer 和材质槽精确恢复。
- 环境、UI、动画、角色切换、物理骨骼脚本未改动。
- `Citlali_ToonBodySkin.shader` 保留；其材质迁移时继续使用原 LightMap、法线和纹身。
- 原始文件备份位于工作区 `ShaderReview/Original/`，逐文件变更清单位于 `ShaderReview/migration.json`。

## 调整顺序

1. 基础贴图用 `_MainTex`；法线用 `_BumpMap`，贴图 Import Settings 应设为 Normal map。
2. 有视频 Ramp 时开启 `Use Video RGB Ramp`；RGB 分别控制三层 Tint，Tint 的 Alpha 控制该层强度。Ramp 建议 Clamp、无 Mipmap；本次保留原贴图导入配置，不统一改动其他材质共享的资源。
3. 无 Ramp 的新角色用 `Shadow Threshold`、`Shadow Softness` 和 `Shadow Tint` 调节分色。
4. 头发先调 `Specular Strength`，再调 `Specular Exponent`、`Anisotropic Highlight`、`Highlight Shift`。方向依赖模型 UV 切线，方向不适配时将各向异性降到 0。
5. `Outline Width (Pixels)` 使用屏幕像素宽度，默认 1；皮肤默认 0.75。轮廓仍依赖模型顶点法线，硬法线分裂接缝可能需要在建模端平滑法线。

## 贴图约定

- `_AOMap.R`：AO，白色为无遮挡。
- `_LightMap.R/G`：阴影阈值偏移/AO；仅存在该图时启用。不同模型的 Lightmap 通道可能不同，不能把任意贴图直接代入。
- `_SpecMap.R/A`：高光遮罩/光滑度；未配置时关闭贴图强度。
- `_TattooTex.RGBA`：颜色与透明度；空纹身图的混合强度设为 0，避免覆盖底色。
- `_EnvMap`：Cubemap，支持旋转和粗糙度。没有环境图时默认强度 0。
- `_EmissionMap` 与 HDR Emission Color：自发光，默认关闭。

## 眼睛与透明部件

视频眼睛使用局部 0–1 UV，恢复了较保守的 -0.025 视差；茜特菈莉等现有图集眼材质默认视差 0。
请勿在身体图集上直接开启视差，否则虹膜可能采样到邻近图块。
眼睛不在材质内重复执行视频末尾的手动 Gamma/ACES，避免与项目后处理重复。

Alpha Clip 在主光、附加光、描边、投影中使用一致阈值。原透明角色卡片转换为写入深度的裁剪材质；这是硬边透明，不是半透明玻璃或纱。如果需要连续透明，应为该部件另设透明 Shader。

## 验证与打开工程

菜单 `Tools > CS15 > Validate Toon Shaders` 检查五类 Shader 的主光、点光、聚光、方向光与点光阴影变体，报告输出到工程根目录 `ToonValidation/shaders.txt`。
验证菜单不修改当前场景。`ToonShaderValidation.Batch` 仅用于独立批处理，会创建临时渲染场景并退出编辑器，不应在交互编辑会话调用。

改动所在工程是工作区下的 **chashader/CS15c**。如果 Unity 当前打开的是上一级同名 `CS15c` 工程，请从 Unity Hub 打开此目录；上一级工程不会自动获得这些修改。
若此工程的场景已经在编辑器打开，磁盘上的场景变更需要重新加载后才能看到，避免用旧的内存场景覆盖磁盘改动。

### 本次验证结果

- Unity 2020.3.48f1c1 / Direct3D 11：五类 Shader 均受支持，所测 30 个主光、附加光与投影变体无编译错误。
- 莱莎、茜特菈莉 01 的实际 Prefab 渲染已检查；预览和编译报告保存在工作区 `ShaderReview/Validation/ToonValidation/`。
- 127 个已迁移材质的 Shader GUID 均可解析，原文件备份齐全；主场景不再引用 Debugger 材质。
- 茜特菈莉 02 在无动画的独立 Prefab 预览中存在明显骨骼变形；换回 Unity 内置 `Unlit/Texture` 后同样变形（`character-2-unlit-reference.png`），因此未将它当成 Shader 问题修改骨骼。主场景的动画状态还需在交互运行时确认。
- 本次没有切换用户当前打开的其他工程，没有执行主场景动画交互测试。
