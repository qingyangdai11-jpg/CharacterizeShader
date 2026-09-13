using UnityEngine;
using UnityEditor;
using UnityEditor.SceneManagement;
using System.Collections.Generic;

[InitializeOnLoad]
public class FixCitlaliColliders
{
    static FixCitlaliColliders()
    {
        // Automatically check on editor update / reload
        EditorApplication.delayCall += () =>
        {
            ApplyFix(false);
        };
    }

    [MenuItem("Tools/修复茜特菈莉02裙子穿模 (Fix Skirt Collision)")]
    public static void ManualFix()
    {
        ApplyFix(true);
    }

    public static void ApplyFix(bool logVerbose)
    {
        var char02 = GameObject.Find("茜特菈莉02 (1)");
        if (char02 == null)
        {
            if (logVerbose) Debug.LogWarning("[FixCitlaliColliders] 场景中未找到 '茜特菈莉02 (1)' 对象。");
            return;
        }

        Transform armature = char02.transform.Find("Armature");
        if (armature == null)
        {
            if (logVerbose) Debug.LogWarning("[FixCitlaliColliders] 未找到 Armature。");
            return;
        }

        // 1. 获取右腿骨骼
        Transform rightUpper = FindDeepChild(armature, "RightUpperLeg");
        Transform rightLower = FindDeepChild(armature, "RightLowerLeg");
        Transform leftUpper = FindDeepChild(armature, "LeftUpperLeg");
        Transform leftLower = FindDeepChild(armature, "LeftLowerLeg");

        if (rightUpper == null || rightLower == null)
        {
            if (logVerbose) Debug.LogError("[FixCitlaliColliders] 未找到 RightUpperLeg 或 RightLowerLeg 骨骼！");
            return;
        }

        // 2. 配置右大腿碰撞体 (RightUpperLeg)
        var rightUpperCol = rightUpper.GetComponent<DynamicBoneCollider>();
        if (rightUpperCol == null) rightUpperCol = rightUpper.gameObject.AddComponent<DynamicBoneCollider>();
        Undo.RecordObject(rightUpperCol, "Fix RightUpperLeg Collider");
        rightUpperCol.m_Direction = DynamicBoneColliderBase.Direction.Y;
        rightUpperCol.m_Center = new Vector3(0f, 0.003f, 0f);
        rightUpperCol.m_Bound = DynamicBoneColliderBase.Bound.Outside;
        rightUpperCol.m_Radius = 0.003f;   // 11cm 世界半径，完全包裹大腿与服饰
        rightUpperCol.m_Height = 0.004f;   // 26cm 世界高度
        EditorUtility.SetDirty(rightUpperCol);

        // 3. 配置右小腿碰撞体 (RightLowerLeg)
        var rightLowerCol = rightLower.GetComponent<DynamicBoneCollider>();
        if (rightLowerCol == null) rightLowerCol = rightLower.gameObject.AddComponent<DynamicBoneCollider>();
        Undo.RecordObject(rightLowerCol, "Fix RightLowerLeg Collider");
        rightLowerCol.m_Direction = DynamicBoneColliderBase.Direction.Y;
        rightLowerCol.m_Center = new Vector3(0f, 0.0015f, 0f);
        rightLowerCol.m_Bound = DynamicBoneColliderBase.Bound.Outside;
        rightLowerCol.m_Radius = 0.00085f;  // 8.5cm 世界半径
        rightLowerCol.m_Height = 0.0032f;   // 32cm 世界高度
        EditorUtility.SetDirty(rightLowerCol);

        // 4. 修复左腿碰撞体（防止原先默认的0.5大半径干扰）
        if (leftUpper != null)
        {
            var leftUpperCol = leftUpper.GetComponent<DynamicBoneCollider>();
            if (leftUpperCol != null)
            {
                Undo.RecordObject(leftUpperCol, "Fix LeftUpperLeg Collider");
                leftUpperCol.m_Direction = DynamicBoneColliderBase.Direction.Y;
                leftUpperCol.m_Center = new Vector3(0f, 0.0011f, 0f);
                leftUpperCol.m_Bound = DynamicBoneColliderBase.Bound.Outside;
                leftUpperCol.m_Radius = 0.0011f;
                leftUpperCol.m_Height = 0.0026f;
                EditorUtility.SetDirty(leftUpperCol);
            }
        }
        if (leftLower != null)
        {
            var leftLowerCol = leftLower.GetComponent<DynamicBoneCollider>();
            if (leftLowerCol != null)
            {
                Undo.RecordObject(leftLowerCol, "Fix LeftLowerLeg Collider");
                leftLowerCol.m_Direction = DynamicBoneColliderBase.Direction.Y;
                leftLowerCol.m_Center = new Vector3(0f, 0.0015f, 0f);
                leftLowerCol.m_Bound = DynamicBoneColliderBase.Bound.Outside;
                leftLowerCol.m_Radius = 0.00085f;
                leftLowerCol.m_Height = 0.0032f;
                EditorUtility.SetDirty(leftLowerCol);
            }
        }

        // 5. 配置裙子 7 根骨骼链的 DynamicBone
        var dbs = char02.GetComponentsInChildren<DynamicBone>(true);
        int skirtFixed = 0;
        foreach (var db in dbs)
        {
            if (db.m_Root != null && db.m_Root.name.Contains("Skirt"))
            {
                Undo.RecordObject(db, "Fix Skirt DynamicBone");

                // 增大粒子碰撞球半径至 0.00055 (世界空间 5.5cm)，填补相邻骨骼链之间 14cm 的物理缝隙
                db.m_Radius = 0.00055f;

                // 调小惯性阻尼，避免腿部快速前摆时裙子因惯性滞后而陷进腿内
                db.m_Inert = 0.15f;
                db.m_Damping = 0.25f;
                db.m_Elasticity = 0.55f;
                db.m_Stiffness = 0.65f;

                // 确保碰撞体列表包含右腿上下段
                if (db.m_Colliders == null) db.m_Colliders = new List<DynamicBoneColliderBase>();
                if (!db.m_Colliders.Contains(rightUpperCol)) db.m_Colliders.Add(rightUpperCol);
                if (!db.m_Colliders.Contains(rightLowerCol)) db.m_Colliders.Add(rightLowerCol);

                EditorUtility.SetDirty(db);
                skirtFixed++;
            }
        }

        EditorSceneManager.MarkSceneDirty(EditorSceneManager.GetActiveScene());
        Debug.Log($"<color=green>[FixCitlaliColliders] 成功修复裙子碰撞！已更新右腿碰撞体并优化 {skirtFixed} 根裙子DynamicBone链！</color>");
    }

    private static Transform FindDeepChild(Transform parent, string name)
    {
        if (parent.name == name) return parent;
        for (int i = 0; i < parent.childCount; i++)
        {
            var result = FindDeepChild(parent.GetChild(i), name);
            if (result != null) return result;
        }
        return null;
    }
}
