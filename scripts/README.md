# 🎮 统一角色架构系统

## 📋 概述

这是一个为Godot游戏引擎设计的统一角色系统，包含Buff状态管理和可编辑的AI系统。支持玩家和敌人角色的统一管理，具有高度的可扩展性。

## 🏗️ 架构设计

### 核心组件

```
📁 scripts/
├── 🎭 CharacterBase.gd           # 角色基类
├── 📋 BuffSystem.gd              # Buff状态系统
├── 🎮 PlayerCharacter.gd         # 玩家角色类
├── 👹 EnemyCharacter.gd          # 敌人角色类
├── 📁 AI/
│   ├── 🤖 AIBase.gd              # AI基础类
│   ├── ⚔️ AggressiveAI.gd        # 攻击型AI
│   └── 🛡️ DefensiveAI.gd         # 防御型AI
└── 📁 examples/
    ├── BuffSystemExample.gd      # Buff系统使用示例
    └── AISystemExample.gd        # AI系统使用示例
```

## 🎭 角色基类系统

### CharacterBase 特性

- **统一属性管理**：血量、魔法值、速度、攻击力等
- **状态机系统**：IDLE、MOVING、ATTACKING、CASTING_SKILL、STUNNED、DEAD
- **Buff系统集成**：自动管理各种状态效果
- **攻击系统**：统一的攻击接口和冷却管理
- **视觉反馈**：受伤闪烁、震动效果、死亡动画等

### 继承结构

```gdscript
CharacterBase (基类)
├── PlayerCharacter (玩家)
│   ├── 输入处理系统
│   ├── 技能状态管理
│   ├── 经验等级系统
│   └── 相机控制
└── EnemyCharacter (敌人)
    ├── AI控制系统
    ├── 血条显示
    ├── 奖励掉落
    └── 房间管理
```

## 📋 Buff状态系统

### 支持的Buff类型

| Buff类型 | 效果描述 | 分类 |
|----------|----------|------|
| 🐌 SLOW | 减速移动 | 负面 |
| 😵 STUN | 眩晕无法行动 | 负面 |
| ☠️ POISON | 持续伤害 | 负面 |
| 🔇 SILENCE | 无法释放技能 | 负面 |
| 💪 STRENGTHEN | 攻击力提升 | 正面 |
| 🛡️ SHIELD | 护盾保护 | 正面 |
| 💚 REGENERATION | 持续回血 | 正面 |
| 🔮 MANA_REGEN | 持续回蓝 | 正面 |
| 💨 SPEED_BOOST | 移动加速 | 正面 |
| ⚔️ DAMAGE_BOOST | 伤害加成 | 正面 |

### Buff使用示例

```gdscript
# 应用减速Buff
character.buff_system.apply_buff(BuffSystem.BuffType.SLOW, 5.0, 0.5)

# 检查是否有Buff
if character.buff_system.has_buff(BuffSystem.BuffType.POISON):
    print("角色中毒了！")

# 清除所有负面Buff
character.buff_system.clear_buffs_by_category(BuffSystem.BuffCategory.DEBUFF)
```

## 🤖 AI系统

### AI类型

| AI类型 | 特点 | 适用场景 |
|--------|------|----------|
| 🟢 PASSIVE | 被动型，不主动攻击 | 中性NPC、胆小怪物 |
| 🔴 AGGRESSIVE | 攻击型，主动冲锋 | 近战战士、狂暴怪物 |
| 🔵 DEFENSIVE | 防御型，保持距离 | 弓箭手、法师怪物 |
| 🟡 BERSERKER | 狂暴型，血量低时更猛 | Boss、精英怪物 |
| 🟣 SUPPORT | 支援型，治疗队友 | 治疗师、辅助怪物 |

### AI状态机

```
IDLE (空闲) → PATROL (巡逻) → CHASE (追击) → ATTACK (攻击)
     ↕               ↕              ↕           ↕
SEARCH (搜索) ← RETREAT (撤退) ← STUNNED (眩晕)
```

### AI配置参数

```gdscript
# 感知配置
detection_range: float = 300.0      # 检测范围
attack_range: float = 100.0         # 攻击范围
lose_target_distance: float = 500.0 # 失去目标距离

# 行为配置
aggression_level: float = 1.0       # 攻击性
intelligence_level: float = 1.0     # 智能程度
reaction_time: float = 0.5          # 反应时间

# 移动配置
movement_style: String = "direct"   # 移动风格
preferred_distance: float = 80.0    # 偏好距离
```

## 🎮 使用方法

### 1. 创建玩家角色

```gdscript
# 场景中使用
var player = PlayerCharacter.new()
player.position = Vector2(100, 100)
add_child(player)

# 应用Buff
player.apply_player_buff(BuffSystem.BuffType.STRENGTHEN, 10.0, 1.5)
```

### 2. 创建敌人角色

```gdscript
# 使用工厂方法创建
var enemy = EnemyCharacter.create_enemy("orc", Vector2(200, 200))
enemy.ai_type = AIBase.AIType.AGGRESSIVE
add_child(enemy)

# 动态切换AI类型
enemy.set_ai_type(AIBase.AIType.DEFENSIVE)
```

### 3. 自定义AI行为

```gdscript
class CustomAI extends AIBase:
    func execute_attack_behavior() -> void:
        super.execute_attack_behavior()
        # 自定义攻击逻辑
        if randf() < 0.3:
            owner_character.cast_enemy_skill("heal_self")
```

## 🔧 扩展指南

### 添加新的Buff类型

1. 在 `BuffSystem.gd` 中添加新的 `BuffType` 枚举值
2. 在 `_apply_buff_effect()` 中添加效果实现
3. 在 `_remove_buff_effect()` 中添加清除逻辑
4. 在 `get_buff_category()` 中设置分类

### 创建新的AI类型

1. 继承 `AIBase` 类
2. 重写 `_init()` 设置AI参数
3. 重写状态行为方法（如 `execute_chase_behavior()`）
4. 在 `EnemyCharacter.gd` 的 `get_ai_class_by_type()` 中注册

### 扩展角色能力

1. 继承 `CharacterBase` 类
2. 重写虚方法实现自定义行为
3. 添加特有属性和方法
4. 集成Buff和AI系统

## 🚀 性能优化

- **AI决策频率**：默认1秒更新一次，可根据需要调整
- **感知更新**：默认0.2秒更新一次感知信息
- **Buff更新**：默认0.5秒更新一次Buff状态
- **内存管理**：自动清理过期的Timer和Buff

## 🐛 调试功能

### 获取调试信息

```gdscript
# 角色调试信息
var debug_info = character.get_debug_info()
print("血量: ", debug_info.health)
print("状态: ", debug_info.state)
print("Buff数量: ", debug_info.buffs_count)

# AI调试信息（敌人）
if enemy.ai_controller:
    print("AI状态: ", enemy.get_ai_state())
    print("AI类型: ", enemy.get_ai_type_name())
```

### 监控AI状态

```gdscript
# 实时监控所有敌人的AI状态
func monitor_ai_states():
    var enemies = get_tree().get_nodes_in_group("enemies")
    for enemy in enemies:
        var info = enemy.get_debug_info()
        print(enemy.character_name, " - 状态:", info.ai_state)
```

## 📝 注意事项

1. **类型安全**：由于Godot 4的类型系统限制，部分类型声明使用了运行时检查
2. **文件依赖**：确保所有脚本文件路径正确，系统会自动检查文件存在性
3. **信号连接**：Buff和AI系统会自动连接相关信号，无需手动处理
4. **性能考虑**：大量角色时注意调整更新频率以保持性能

## 🎯 最佳实践

1. **统一接口**：优先使用基类提供的方法而不是直接修改属性
2. **Buff管理**：使用分类清除和批量操作来优化性能
3. **AI配置**：根据游戏需求合理设置AI参数，避免过于频繁的状态切换
4. **扩展性**：新功能优先考虑扩展现有系统而不是重写

---

💡 **提示**：查看 `scripts/examples/` 目录中的示例代码了解详细用法！
