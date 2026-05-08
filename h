[gd_scene format=3 uid="uid://ce5845ps3tvf0"]

[ext_resource type="Texture2D" uid="uid://dphty2mdodtae" path="res://scripts/shop/ui/bg_shop_counter.png" id="1_bg"]
[ext_resource type="Texture2D" uid="uid://dkxwgpaqjxj8h" path="res://scripts/shop/ui/ui_panel_adventurer.png" id="2_panel_adv"]
[ext_resource type="Texture2D" uid="uid://b6l1x6puq5mws" path="res://scripts/shop/ui/ui_panel_inventory.png" id="3_panel_inv"]
[ext_resource type="Texture2D" uid="uid://bvbm05qu4237x" path="res://scripts/shop/ui/btn_acquire.png" id="4_btn_acquire"]
[ext_resource type="Texture2D" uid="uid://co850ra6qg1yb" path="res://scripts/shop/ui/btn_bargain.png" id="5_btn_bargain"]
[ext_resource type="Texture2D" uid="uid://cl8xi3wi4y3of" path="res://scripts/shop/ui/btn_refuse.png" id="6_btn_refuse"]
[ext_resource type="Texture2D" uid="uid://dptrll2adke7j" path="res://scripts/shop/ui/btn_put_on_sale.png" id="7_btn_sale"]
[ext_resource type="Texture2D" uid="uid://b4wuwv0mf5x3v" path="res://scripts/shop/ui/btn_business_log.png" id="8_btn_bizlog"]
[ext_resource type="Texture2D" uid="uid://b1twv4y7d3kvq" path="res://scripts/shop/ui/btn_sales_record.png" id="9_btn_sale_rec"]
[ext_resource type="Texture2D" uid="uid://i4wwcaaquqtg" path="res://scripts/shop/ui/btn_ecology_panel.png" id="10_btn_eco"]
[ext_resource type="Texture2D" uid="uid://bxk872y1brcfi" path="res://scripts/shop/ui/btn_end_day.png" id="11_btn_end"]
[ext_resource type="Script" uid="uid://cbwi6o0y0lce0" path="res://ShopManager.gd" id="12_script"]

[node name="ShopRoot" type="Node2D" unique_id=1098518206]
script = ExtResource("12_script")

[node name="ShopBackground" type="TextureRect" parent="." unique_id=1477831274]
offset_right = 2752.0
offset_bottom = 1536.0
texture = ExtResource("1_bg")
stretch_mode = 2

[node name="UILayer" type="Control" parent="." unique_id=627059676]
z_index = 10
layout_mode = 3
anchors_preset = 0
offset_right = 2752.0
offset_bottom = 1536.0
mouse_filter = 2

[node name="TopBar" type="Control" parent="UILayer" unique_id=1719438455]
anchors_preset = 0
offset_right = 2752.0
offset_bottom = 85.0

[node name="Status_Gold" type="Control" parent="UILayer/TopBar" unique_id=1123816307]
anchors_preset = 0
offset_left = 30.0
offset_top = 20.0
offset_right = 430.0
offset_bottom = 80.0

[node name="Label" type="Label" parent="UILayer/TopBar/Status_Gold" unique_id=602474512]
layout_mode = 0
offset_left = 5.0
offset_top = 5.0
offset_right = 395.0
offset_bottom = 55.0
theme_override_colors/font_color = Color(1, 0.843, 0, 1)
text = "12,450"

[node name="Status_Reputation" type="Control" parent="UILayer/TopBar" unique_id=1428942960]
anchors_preset = 0
offset_left = 450.0
offset_top = 20.0
offset_right = 850.0
offset_bottom = 80.0

[node name="Label" type="Label" parent="UILayer/TopBar/Status_Reputation" unique_id=397233514]
layout_mode = 0
offset_left = 5.0
offset_top = 5.0
offset_right = 395.0
offset_bottom = 55.0
theme_override_colors/font_color = Color(0.678, 0.847, 1, 1)
text = "68"

[node name="Status_Days" type="Control" parent="UILayer/TopBar" unique_id=1478607339]
anchors_preset = 0
offset_left = 870.0
offset_top = 20.0
offset_right = 1270.0
offset_bottom = 80.0

[node name="Label" type="Label" parent="UILayer/TopBar/Status_Days" unique_id=613021225]
layout_mode = 0
offset_left = 5.0
offset_top = 5.0
offset_right = 395.0
offset_bottom = 55.0
text = "第23天"

[node name="Status_Decor" type="Control" parent="UILayer/TopBar" unique_id=1212730294]
anchors_preset = 0
offset_left = 1290.0
offset_top = 20.0
offset_right = 1710.0
offset_bottom = 80.0

[node name="Label" type="Label" parent="UILayer/TopBar/Status_Decor" unique_id=1804916980]
layout_mode = 0
offset_left = 5.0
offset_top = 5.0
offset_right = 415.0
offset_bottom = 55.0
text = "装饰 Lv.1"

[node name="Status_Counter" type="Control" parent="UILayer/TopBar" unique_id=446928906]
anchors_preset = 0
offset_left = 1730.0
offset_top = 20.0
offset_right = 2150.0
offset_bottom = 80.0

[node name="Label" type="Label" parent="UILayer/TopBar/Status_Counter" unique_id=862227430]
layout_mode = 0
offset_left = 5.0
offset_top = 5.0
offset_right = 415.0
offset_bottom = 55.0
text = "柜台 Lv.1"

[node name="Status_Safe" type="Control" parent="UILayer/TopBar" unique_id=191907118]
anchors_preset = 0
offset_left = 2170.0
offset_top = 20.0
offset_right = 2690.0
offset_bottom = 80.0

[node name="Label" type="Label" parent="UILayer/TopBar/Status_Safe" unique_id=197577138]
layout_mode = 0
offset_left = 5.0
offset_top = 5.0
offset_right = 515.0
offset_bottom = 55.0
text = "保险箱 Lv.1"

[node name="Panel_Adventurer" type="NinePatchRect" parent="UILayer" unique_id=195074653]
layout_mode = 0
offset_left = 1820.0
offset_top = 100.0
offset_right = 2404.0
offset_bottom = 689.0
texture = ExtResource("2_panel_adv")
patch_margin_left = 16
patch_margin_top = 16
patch_margin_right = 16
patch_margin_bottom = 16

[node name="Title" type="Label" parent="UILayer/Panel_Adventurer" unique_id=986522335]
layout_mode = 0
offset_left = 20.0
offset_top = 15.0
offset_right = 350.0
offset_bottom = 55.0
text = "冒险者信息"

[node name="Avatar" type="TextureRect" parent="UILayer/Panel_Adventurer" unique_id=123809947]
layout_mode = 0
offset_left = 20.0
offset_top = 75.0
offset_right = 120.0
offset_bottom = 185.0

[node name="Label_Name" type="Label" parent="UILayer/Panel_Adventurer" unique_id=46887791]
layout_mode = 0
offset_left = 140.0
offset_top = 75.0
offset_right = 560.0
offset_bottom = 110.0
text = "名称："

[node name="Label_Class" type="Label" parent="UILayer/Panel_Adventurer" unique_id=619732691]
layout_mode = 0
offset_left = 140.0
offset_top = 110.0
offset_right = 560.0
offset_bottom = 140.0
text = "职业："

[node name="Label_Level" type="Label" parent="UILayer/Panel_Adventurer" unique_id=1578464571]
layout_mode = 0
offset_left = 140.0
offset_top = 140.0
offset_right = 560.0
offset_bottom = 170.0
text = "等级："

[node name="Label_Rep" type="Label" parent="UILayer/Panel_Adventurer" unique_id=1435521369]
layout_mode = 0
offset_left = 140.0
offset_top = 170.0
offset_right = 560.0
offset_bottom = 200.0
text = "信誉："

[node name="Label_Relation" type="Label" parent="UILayer/Panel_Adventurer" unique_id=2090166763]
layout_mode = 0
offset_left = 20.0
offset_top = 200.0
offset_right = 560.0
offset_bottom = 235.0
text = "友善 68/100"

[node name="ItemIcon" type="TextureRect" parent="UILayer/Panel_Adventurer" unique_id=1392174342]
layout_mode = 0
offset_left = 20.0
offset_top = 260.0
offset_right = 120.0
offset_bottom = 370.0

[node name="Label_ItemName" type="Label" parent="UILayer/Panel_Adventurer" unique_id=2105665422]
layout_mode = 0
offset_left = 140.0
offset_top = 260.0
offset_right = 560.0
offset_bottom = 295.0
text = "物品名称"

[node name="Label_ItemDesc" type="Label" parent="UILayer/Panel_Adventurer" unique_id=1576608387]
layout_mode = 0
offset_left = 140.0
offset_top = 295.0
offset_right = 560.0
offset_bottom = 335.0
text = "物品描述"

[node name="Label_Price" type="Label" parent="UILayer/Panel_Adventurer" unique_id=2109349031]
layout_mode = 0
offset_left = 140.0
offset_top = 335.0
offset_right = 560.0
offset_bottom = 375.0
text = "建议价: 500 金币"

[node name="Btn_Acquire" type="Button" parent="UILayer/Panel_Adventurer" unique_id=1359087234]
layout_mode = 0
offset_left = 15.0
offset_top = 490.0
offset_right = 195.0
offset_bottom = 560.0
icon = ExtResource("4_btn_acquire")
flat = true

[node name="Btn_Bargain" type="Button" parent="UILayer/Panel_Adventurer" unique_id=130559962]
layout_mode = 0
offset_left = 205.0
offset_top = 490.0
offset_right = 385.0
offset_bottom = 560.0
icon = ExtResource("5_btn_bargain")
flat = true

[node name="Btn_Refuse" type="Button" parent="UILayer/Panel_Adventurer" unique_id=1109685739]
layout_mode = 0
offset_left = 395.0
offset_top = 490.0
offset_right = 575.0
offset_bottom = 560.0
icon = ExtResource("6_btn_refuse")
flat = true

[node name="Panel_Inventory" type="NinePatchRect" parent="UILayer" unique_id=772959542]
layout_mode = 0
offset_left = 1820.0
offset_top = 700.0
offset_right = 2406.0
offset_bottom = 1261.0
texture = ExtResource("3_panel_inv")
patch_margin_left = 16
patch_margin_top = 16
patch_margin_right = 16
patch_margin_bottom = 16

[node name="Title" type="Label" parent="UILayer/Panel_Inventory" unique_id=1952251996]
layout_mode = 0
offset_left = 20.0
offset_top = 15.0
offset_right = 400.0
offset_bottom = 55.0
text = "库存（23/40）"

[node name="Label_PriceTag" type="Label" parent="UILayer/Panel_Inventory" unique_id=1386744707]
layout_mode = 0
offset_left = 20.0
offset_top = 75.0
offset_right = 80.0
offset_bottom = 115.0
text = "售价"

[node name="Input_SellPrice" type="LineEdit" parent="UILayer/Panel_Inventory" unique_id=232979673]
layout_mode = 0
offset_left = 95.0
offset_top = 70.0
offset_right = 280.0
offset_bottom = 120.0
placeholder_text = "输入售价"

[node name="Btn_PutOnSale" type="Button" parent="UILayer/Panel_Inventory" unique_id=1292263700]
layout_mode = 0
offset_left = 300.0
offset_top = 70.0
offset_right = 550.0
offset_bottom = 120.0
icon = ExtResource("7_btn_sale")
flat = true

[node name="Label_Header" type="Label" parent="UILayer/Panel_Inventory" unique_id=1517745508]
layout_mode = 0
offset_left = 20.0
offset_top = 140.0
offset_right = 560.0
offset_bottom = 180.0
text = "物品名称                数量        单价"

[node name="Scroll_Inventory" type="ScrollContainer" parent="UILayer/Panel_Inventory" unique_id=1171847392]
layout_mode = 0
offset_left = 20.0
offset_top = 190.0
offset_right = 560.0
offset_bottom = 480.0

[node name="InventoryList" type="VBoxContainer" parent="UILayer/Panel_Inventory/Scroll_Inventory" unique_id=475088922]
layout_mode = 2

; 业务功能栏 - 底部4个按钮的外部框
[node name="Panel_BusinessFunctionBar" type="NinePatchRect" parent="UILayer" unique_id=1729427385]
layout_mode = 0
offset_left = 2150.0
offset_top = 1270.0
offset_right = 2750.0
offset_bottom = 1500.0
texture = ExtResource("16_funcbar")
patch_margin_left = 16
patch_margin_top = 16
patch_margin_right = 16
patch_margin_bottom = 16

[node name="Btn_BusinessLog" type="Button" parent="UILayer/Panel_BusinessFunctionBar" unique_id=468472388]
layout_mode = 0
offset_left = 27.0
offset_top = 34.0
offset_right = 148.0
offset_bottom = 196.0
icon = ExtResource("8_btn_bizlog")
flat = true

[node name="Btn_SalesRecord" type="Button" parent="UILayer/Panel_BusinessFunctionBar" unique_id=7664722]
layout_mode = 0
offset_left = 161.0
offset_top = 30.0
offset_right = 282.0
offset_bottom = 191.0
icon = ExtResource("9_btn_sale_rec")
flat = true

[node name="Btn_EcologyPanel" type="Button" parent="UILayer/Panel_BusinessFunctionBar" unique_id=191540542]
layout_mode = 0
offset_left = 295.0
offset_top = 27.0
offset_right = 423.0
offset_bottom = 188.0
icon = ExtResource("10_btn_eco")
flat = true

[node name="Btn_EndDay" type="Button" parent="UILayer/Panel_BusinessFunctionBar" unique_id=1559644074]
layout_mode = 0
offset_left = 441.0
offset_top = 26.0
offset_right = 587.0
offset_bottom = 188.0
icon = ExtResource("11_btn_end")
flat = true
