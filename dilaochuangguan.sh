#!/bin/bash

# ==========================
# 地牢闯关游戏 - Bash 版本
# ==========================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 无色

# 带颜色输出函数
print_error()   { echo -e "${RED}$1${NC}"; }
print_success() { echo -e "${GREEN}$1${NC}"; }
print_warning() { echo -e "${YELLOW}$1${NC}"; }
print_info()    { echo -e "${BLUE}$1${NC}"; }

# 玩家初始属性
PLAYER_HP=100
PLAYER_MAX_HP=100
PLAYER_ATK=15
PLAYER_DEF=2
INVENTORY=()            # 背包数组，最多3个物品

# 游戏设置
FLOORS=5
CURRENT_FLOOR=1

# 显示玩家状态
show_status() {
    echo "=============================="
    echo -e "层数: $CURRENT_FLOOR/$FLOORS"
    echo -e "HP: $PLAYER_HP/$PLAYER_MAX_HP"
    echo -e "攻击力: $PLAYER_ATK"
    echo -e "防御力: $PLAYER_DEF"
    echo -n "背包: "
    if [ ${#INVENTORY[@]} -eq 0 ]; then
        echo "空"
    else
        echo "${INVENTORY[@]}"
    fi
    echo "=============================="
}

# 添加物品到背包
add_item() {
    local item=$1
    if [ ${#INVENTORY[@]} -lt 3 ]; then
        INVENTORY+=("$item")
        print_success "获得了 $item！"
    else
        print_warning "背包已满，无法获得 $item。"
    fi
}

# 使用物品
use_item() {
    if [ ${#INVENTORY[@]} -eq 0 ]; then
        print_warning "背包中没有物品！"
        return 1
    fi
    echo "背包中的物品:"
    for i in "${!INVENTORY[@]}"; do
        echo "$((i+1))) ${INVENTORY[$i]}"
    done
    echo "$(( ${#INVENTORY[@]}+1 ))) 取消"
    read -p "选择要使用的物品: " item_choice

    # 取消选择
    if [ "$item_choice" -eq "$(( ${#INVENTORY[@]}+1 ))" ] 2>/dev/null; then
        return 1
    fi

    # 验证输入
    if ! [[ "$item_choice" =~ ^[0-9]+$ ]] || [ "$item_choice" -lt 1 ] || [ "$item_choice" -gt ${#INVENTORY[@]} ]; then
        echo "无效选择。"
        return 1
    fi

    local index=$((item_choice-1))
    local item=${INVENTORY[$index]}
    case $item in
        "血瓶")
            PLAYER_HP=$((PLAYER_HP + 20))
            [ $PLAYER_HP -gt $PLAYER_MAX_HP ] && PLAYER_HP=$PLAYER_MAX_HP
            print_success "使用了血瓶，恢复了 20 HP！"
            unset 'INVENTORY[$index]'
            INVENTORY=("${INVENTORY[@]}")   # 重新索引数组
            ;;
        "攻击药水")
            PLAYER_ATK=$((PLAYER_ATK + 5))
            print_success "使用了攻击药水，攻击力永久增加 5！"
            unset 'INVENTORY[$index]'
            INVENTORY=("${INVENTORY[@]}")
            ;;
        *)
            print_warning "未知物品。"
            return 1
            ;;
    esac
    return 0
}

# 战斗函数
# 参数: 怪物名 怪物HP 怪物攻击 怪物防御
# 返回值: 0-胜利, 1-玩家死亡, 2-逃跑成功
fight() {
    local name=$1
    local m_hp=$2
    local m_atk=$3
    local m_def=$4

    while [ $m_hp -gt 0 ] && [ $PLAYER_HP -gt 0 ]; do
        echo ""
        echo "你的 HP: $PLAYER_HP/$PLAYER_MAX_HP, 怪物 HP: $m_hp"
        echo "选择行动:"
        echo "1) 攻击"
        echo "2) 使用物品"
        echo "3) 逃跑"
        read -p "输入选择 (1-3): " choice

        case $choice in
            1)  # 攻击
                # 玩家伤害 = (玩家攻击 - 怪物防御) ± 随机
                local player_damage=$((PLAYER_ATK - m_def + RANDOM % 5 - 2))
                [ $player_damage -lt 1 ] && player_damage=1
                m_hp=$((m_hp - player_damage))
                print_success "你对 $name 造成了 $player_damage 点伤害！"

                if [ $m_hp -le 0 ]; then
                    print_success "你击败了 $name！"
                    # 随机掉落
                    local drop=$((RANDOM % 3))
                    if [ $drop -eq 0 ]; then
                        echo "怪物掉落了一个血瓶！"
                        add_item "血瓶"
                    elif [ $drop -eq 1 ]; then
                        echo "怪物掉落了一个攻击药水！"
                        add_item "攻击药水"
                    fi
                    return 0   # 胜利
                fi

                # 怪物反击
                local monster_damage=$((m_atk - PLAYER_DEF + RANDOM % 5 - 2))
                [ $monster_damage -lt 1 ] && monster_damage=1
                PLAYER_HP=$((PLAYER_HP - monster_damage))
                print_error "$name 对你造成了 $monster_damage 点伤害！"

                if [ $PLAYER_HP -le 0 ]; then
                    print_error "你死了..."
                    return 1   # 玩家死亡
                fi
                ;;

            2)  # 使用物品
                use_item
                if [ $? -eq 1 ]; then
                    # 无物品或取消，重新选择（不消耗回合）
                    continue
                fi
                # 怪物回合
                local monster_damage=$((m_atk - PLAYER_DEF + RANDOM % 5 - 2))
                [ $monster_damage -lt 1 ] && monster_damage=1
                PLAYER_HP=$((PLAYER_HP - monster_damage))
                print_error "$name 对你造成了 $monster_damage 点伤害！"
                if [ $PLAYER_HP -le 0 ]; then
                    print_error "你死了..."
                    return 1
                fi
                ;;

            3)  # 逃跑
                # 50% 成功率
                local flee_chance=$((RANDOM % 2))
                if [ $flee_chance -eq 0 ]; then
                    print_success "你成功逃跑了！"
                    return 2   # 逃跑成功
                else
                    print_warning "逃跑失败！"
                    # 怪物攻击
                    local monster_damage=$((m_atk - PLAYER_DEF + RANDOM % 5 - 2))
                    [ $monster_damage -lt 1 ] && monster_damage=1
                    PLAYER_HP=$((PLAYER_HP - monster_damage))
                    print_error "$name 对你造成了 $monster_damage 点伤害！"
                    if [ $PLAYER_HP -le 0 ]; then
                        print_error "你死了..."
                        return 1
                    fi
                fi
                ;;

            *)
                echo "无效选择，请重新输入。"
                ;;
        esac
    done
}

# 遭遇怪物
encounter_monster() {
    local monster_names=("哥布林" "兽人" "骷髅" "巨魔" "恶龙")
    local idx=$((RANDOM % ${#monster_names[@]}))
    local name=${monster_names[$idx]}
    local m_hp=$((20 + CURRENT_FLOOR * 10 + RANDOM % 20))
    local m_atk=$((5 + CURRENT_FLOOR * 3 + RANDOM % 5))
    local m_def=$((1 + CURRENT_FLOOR / 2))

    print_warning "你遇到了一个 $name！"
    print_warning "怪物 HP: $m_hp, 攻击: $m_atk, 防御: $m_def"

    fight "$name" $m_hp $m_atk $m_def
    local result=$?
    if [ $result -eq 1 ]; then
        # 玩家死亡，主循环会处理
        :
    elif [ $result -eq 2 ]; then
        print_info "你逃离了战斗，继续前进。"
    fi
    # 结果为0时，掉落已在 fight 中处理
}

# 遭遇宝箱
encounter_chest() {
    print_success "你发现了一个宝箱！"
    local chest_type=$((RANDOM % 3))
    case $chest_type in
        0)
            echo "宝箱中有一个血瓶！"
            add_item "血瓶"
            ;;
        1)
            echo "宝箱中有一个攻击药水！"
            add_item "攻击药水"
            ;;
        2)
            local heal=$((20 + RANDOM % 20))
            PLAYER_HP=$((PLAYER_HP + heal))
            [ $PLAYER_HP -gt $PLAYER_MAX_HP ] && PLAYER_HP=$PLAYER_MAX_HP
            print_success "宝箱中涌出治疗能量，恢复了 $heal HP！"
            ;;
    esac
}

# 遭遇陷阱
encounter_trap() {
    print_error "你触发了一个陷阱！"
    local damage=$((10 + RANDOM % 20))
    PLAYER_HP=$((PLAYER_HP - damage))
    print_error "陷阱造成了 $damage 点伤害！"
    if [ $PLAYER_HP -le 0 ]; then
        print_error "你死了..."
    fi
}

# 随机事件（根据概率调用具体函数）
random_event() {
    local event=$((RANDOM % 10))
    if [ $event -lt 5 ]; then
        encounter_monster      # 50%
    elif [ $event -lt 8 ]; then
        encounter_chest        # 30%
    else
        encounter_trap         # 20%
    fi
}

# ========== 主游戏循环 ==========
echo "欢迎来到地牢闯关游戏！"
echo "你需要闯过 $FLOORS 层地牢。"
echo "祝你好运！"

while [ $CURRENT_FLOOR -le $FLOORS ] && [ $PLAYER_HP -gt 0 ]; do
    show_status
    echo "你正在进入第 $CURRENT_FLOOR 层..."
    random_event

    # 如果玩家死亡，结束循环
    [ $PLAYER_HP -le 0 ] && break

    echo ""
    read -p "按 Enter 键继续下一层..."
    CURRENT_FLOOR=$((CURRENT_FLOOR + 1))
done

# 游戏结局
if [ $PLAYER_HP -le 0 ]; then
    print_error "游戏结束！你死在了地牢中。"
else
    print_success "恭喜！你成功闯过了所有 $FLOORS 层地牢！"
fi
