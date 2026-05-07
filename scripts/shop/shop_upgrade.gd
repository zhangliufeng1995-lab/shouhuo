extends Node
## 店铺升级模块
## 管理装饰/柜台/保险箱的升级逻辑
## 装饰: 影响冒险者数量（未来功能）
## 柜台: 影响顾客购买意愿
## 保险箱: 增加库存上限（每级+10）

# 升级基础费用
const DECOR_BASE_COST := 300
const COUNTER_BASE_COST := 400
const VAULT_BASE_COST := 500

## 升级装饰 - 影响冒险者来访频率
func upgrade_decor(shop: Node) -> void:
	var cost = DECOR_BASE_COST * shop.get_lv_decor()
	if shop.gold < cost:
		shop.add_log("金币不足，无法升级装饰!", "red")
		return
	shop.gold -= cost
	shop.set_lv_decor(shop.get_lv_decor() + 1)
	shop.add_log("🎨 装饰升级成功! Lv%d" % shop.get_lv_decor())
	shop._update_all_status()

## 升级柜台 - 提升顾客购买意愿
func upgrade_counter(shop: Node) -> void:
	var cost = COUNTER_BASE_COST * shop.get_lv_counter()
	if shop.gold < cost:
		shop.add_log("金币不足，无法升级柜台!", "red")
		return
	shop.gold -= cost
	shop.set_lv_counter(shop.get_lv_counter() + 1)
	shop.add_log("🛒 柜台升级成功! Lv%d" % shop.get_lv_counter())
	shop._update_all_status()

## 升级保险箱 - 增加库存上限
func upgrade_vault(shop: Node) -> void:
	var cost = VAULT_BASE_COST * shop.get_lv_vault()
	if shop.gold < cost:
		shop.add_log("金币不足，无法升级保险箱!", "red")
		return
	shop.gold -= cost
	shop.set_lv_vault(shop.get_lv_vault() + 1)
	shop.add_log(str("🔒 保险箱升级成功! Lv%d，库存上限提升至 %d" % [shop.get_lv_vault(), shop.get_lv_vault() * 10]))
	shop._update_all_status()
