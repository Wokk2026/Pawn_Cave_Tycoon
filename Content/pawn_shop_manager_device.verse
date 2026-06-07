using { /Fortnite.com/Devices }
using { /Fortnite.com/Characters }
using { /Fortnite.com/UI }
using { /Verse.org/Simulation }
using { /Verse.org/Colors }
using { /Verse.org/Random } # <--- EZT AZ EGY SORT ADD HOZZÁ!
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /UnrealEngine.com/Temporary/UI }
using { /UnrealEngine.com/Temporary/SpatialMath }

log_pawn_shop := class(log_channel){}

drop_item_handler := class():
    Manager : pawn_shop_manager_device
    ItemIndex : int
    OnClick(Message : widget_message):void=
        Manager.DropItemFromInventory(ItemIndex, Message.Player)

shelf_slot := class:
    Index : int
    ShelfMarker : creative_prop
    Button : button_device
    Billboard : billboard_device
    Type : shelf_type
    Manager : pawn_shop_manager_device

    var IsEmpty : logic = true
    var PlacedLoot : ?loot_definition = false
    var PlacedProp : ?creative_prop = false

    Init():void=
        ShelfMarker.Hide()
        Billboard.SetText(MakeEmptyShelfText())
        Button.InteractedWithEvent.Subscribe(OnButtonPressed)

    OnButtonPressed(Agent : agent):void=
        if (IsEmpty?):
            Manager.OnShelfPlaceAttempt(Agent, Self)
        else:
            Manager.Logger.Print("A berakott tárgyat már csak a pultnál lévő vevőnek tudod eladni!")

fixed_loot_source := class:
    LootData : loot_definition
    Manager : pawn_shop_manager_device

    Init():void=
        LootData.PickupButton.InteractedWithEvent.Subscribe(OnPickedUp)

    OnPickedUp(Agent : agent):void=
        Manager.OnFixedLootPickedUp(Agent, LootData)

pawn_shop_manager_device := class(creative_device):
    Logger : log = log{Channel := log_pawn_shop}

    # Bekötjük az NPC Agyat a másik fájlból
    var NPCBrain : pawn_npc_brain = pawn_npc_brain{}

    @editable StartingMoney : int = 0
    @editable var MaxWeightCapacity : float = 100.0
    @editable PassiveIncomeTickRate : float = 5.0 
    @editable CashRegisterButton : button_device = button_device{}
    @editable UpgradeBackpackButton : button_device = button_device{}
    @editable BaseUpgradeCost : int = 500
    @editable UpgradeAddedCapacity : float = 50.0
    @editable PaywallButton : button_device = button_device{}
    @editable PaywallCost : int = 2000
    @editable PaywallProps : []creative_prop = array{}
    @editable LootDatabase : []loot_definition = array{}
    @editable ShopShelfMarkers : []creative_prop = array{}
    @editable ShopShelfButtons : []button_device = array{}
    @editable ShopShelfBillboards : []billboard_device = array{}
    @editable MuseumShelfMarkers : []creative_prop = array{}
    @editable MuseumShelfButtons : []button_device = array{}
    @editable MuseumShelfBillboards : []billboard_device = array{}
    @editable NPCNextCustomerButton : button_device = button_device{}
    @editable NPCAcceptButton : button_device = button_device{}
    @editable NPCRejectButton : button_device = button_device{}
    @editable NPCBillboard : billboard_device = billboard_device{}
    @editable ClassSelectors : []class_and_team_selector_device = array{}
    @editable ExtractionZone : mutator_zone_device = mutator_zone_device{}
    @editable ShopTeleporter : teleporter_device = teleporter_device{}
    @editable ShopNPC : character_device = character_device{}
  
    var CurrentRebirthLevel : int = 0
    var UsedLootDefinitions : []loot_definition = array{}
    var ShopShelves : []shelf_slot = array{}
    var MuseumShelves : []shelf_slot = array{}

    var CurrentPlayerMoney : int = 0
    var CurrentBackpackWeight : float = 0.0
    var CurrentUpgradeCost : int = 0
    var CurrentTickIncome : int = 0

    var ActiveNegotiationShelf : ?shelf_slot = false
    var ActiveNPCOffer : int = 0

    var BackpackInventory : []loot_definition = array{}
    var StashInventory : []loot_definition = array{}
    
    # A Felfedezések memóriája
    var DiscoveredItems : [string]logic = map{}
    var PlayerWeightTiers : [player]int = map{}
    
    var CurrentCanvas : ?canvas = false
    var MoneyUI : text_block = text_block{DefaultTextColor := NamedColors.White}
    var WeightUI : text_block = text_block{DefaultTextColor := NamedColors.White}
    var StashUI : text_block = text_block{DefaultTextColor := NamedColors.Yellow}

    OnBegin<override>()<suspends>: void=
        set CurrentPlayerMoney = StartingMoney
        set CurrentUpgradeCost = BaseUpgradeCost
        
        for (Index -> Marker : ShopShelfMarkers, Button := ShopShelfButtons[Index], Billboard := ShopShelfBillboards[Index]):
            Slot := shelf_slot{Index := Index, ShelfMarker := Marker, Button := Button, Billboard := Billboard, Type := shelf_type.Shop, Manager := Self}
            Slot.Init()
            set ShopShelves = ShopShelves + array{Slot}

        for (Index -> Marker : MuseumShelfMarkers, Button := MuseumShelfButtons[Index], Billboard := MuseumShelfBillboards[Index]):
            Slot := shelf_slot{Index := Index, ShelfMarker := Marker, Button := Button, Billboard := Billboard, Type := shelf_type.Museum, Manager := Self}
            Slot.Init()
            set MuseumShelves = MuseumShelves + array{Slot}

        for (LootDef : LootDatabase):
            LootSource := fixed_loot_source{LootData := LootDef, Manager := Self}
            LootSource.Init()
        
        for (Player : GetPlayspace().GetPlayers()):
            CreatePlayerUI(Player)

        ExtractionZone.AgentEntersEvent.Subscribe(OnPlayerExtracted)
        CashRegisterButton.InteractedWithEvent.Subscribe(OnCashRegisterPressed)
        UpgradeBackpackButton.InteractedWithEvent.Subscribe(OnUpgradeBackpackPressed)
        PaywallButton.InteractedWithEvent.Subscribe(OnPaywallPressed)
     
        NPCBillboard.SetText(MakeNPCGreetingText())
        NPCAcceptButton.Disable()
        NPCRejectButton.Disable()
        
        NPCNextCustomerButton.InteractedWithEvent.Subscribe(OnNPCNextCustomerPressed)
        NPCAcceptButton.InteractedWithEvent.Subscribe(OnNPCAcceptPressed)
        NPCRejectButton.InteractedWithEvent.Subscribe(OnNPCRejectPressed)
        
        spawn{PassiveIncomeLoop()}

    PassiveIncomeLoop()<suspends> : void=
        loop:
            Sleep(PassiveIncomeTickRate) 
            if (CurrentTickIncome > 0):
                set CurrentPlayerMoney = CurrentPlayerMoney + CurrentTickIncome
                UpdateUI()

    OnNPCNextCustomerPressed(Agent : agent): void=
        var FullShelves : []shelf_slot = array{}
        for (Slot : ShopShelves, not Slot.IsEmpty?):
            set FullShelves = FullShelves + array{Slot}

        if (FullShelves.Length > 0):
            RandomShelfIndex := GetRandomInt(0, FullShelves.Length - 1)
            if (TargetShelf := FullShelves[RandomShelfIndex], Loot := TargetShelf.PlacedLoot?):
                
                # Itt hívjuk a külső NPC agyat!
                FinalOffer := NPCBrain.CalculateNPCOffer(Loot.SellPrice, CurrentRebirthLevel)
                NPCBrain.PlayNPCDecisionAnimation(Loot.SellPrice, FinalOffer)
                
                set ActiveNegotiationShelf = option{TargetShelf}
                set ActiveNPCOffer = FinalOffer
                
                NPCBillboard.SetText(MakeNPCOfferText(Loot.ItemName, FinalOffer))
                NPCNextCustomerButton.Disable()
                NPCAcceptButton.Enable()
                NPCRejectButton.Enable()
        else:
            NPCBillboard.SetText(MakeNPCNoItemsText())

    OnNPCAcceptPressed(Agent : agent): void=
        if (Slot := ActiveNegotiationShelf?, Prop := Slot.PlacedProp?):
            set CurrentPlayerMoney = CurrentPlayerMoney + ActiveNPCOffer
            Prop.Dispose()
            set Slot.IsEmpty = true
            set Slot.PlacedLoot = false
            set Slot.PlacedProp = false
            Slot.Billboard.SetText(MakeEmptyShelfText())
            Slot.Button.Enable()
            ResetNPCCounter()
            UpdateUI()

    OnNPCRejectPressed(Agent : agent): void=
        ResetNPCCounter()

    ResetNPCCounter(): void=
        set ActiveNegotiationShelf = false
        set ActiveNPCOffer = 0
        NPCBillboard.SetText(MakeNPCGreetingText())
        NPCNextCustomerButton.Enable()
        NPCAcceptButton.Disable()
        NPCRejectButton.Disable()

    OnCashRegisterPressed(Agent : agent): void=
        var ItemsSold : int = 0
        for (Slot : ShopShelves):
            var IsNegotiated : int = 0
            if (ActiveShelf := ActiveNegotiationShelf?, ActiveShelf.Index = Slot.Index):
                set IsNegotiated = 1
                
            if (not Slot.IsEmpty?, IsNegotiated = 0, Loot := Slot.PlacedLoot?, Prop := Slot.PlacedProp?):
                set CurrentPlayerMoney = CurrentPlayerMoney + Loot.SellPrice
                Prop.Dispose()
                set Slot.IsEmpty = true
                set Slot.PlacedLoot = false
                set Slot.PlacedProp = false
                Slot.Billboard.SetText(MakeEmptyShelfText())
                Slot.Button.Enable()
                set ItemsSold = ItemsSold + 1
                    
        if (ItemsSold > 0):
            UpdateUI()
            Logger.Print("Kassza: Szabad bolti tárgyak eladva!")

    OnShelfPlaceAttempt(Agent : agent, Slot : shelf_slot):void=
        if (StashInventory.Length > 0, LastIndex := StashInventory.Length - 1, ItemToPlace := StashInventory[LastIndex]):
            MarkerTransform := Slot.ShelfMarker.GetTransform()
            CorrectedTransform := transform{Translation := MarkerTransform.Translation, Rotation := MarkerTransform.Rotation, Scale := vector3{X := 1.0, Y := 1.0, Z := 1.0}}
            
            if (ActualAsset := ItemToPlace.ItemAsset?, SpawnResult := SpawnProp(ActualAsset, CorrectedTransform), SpawnedProp := SpawnResult(0)?):
                if (NewStash := StashInventory.Slice[0, LastIndex]):
                    set StashInventory = NewStash
                
                set Slot.IsEmpty = false
                set Slot.PlacedLoot = option{ItemToPlace}
                set Slot.PlacedProp = option{SpawnedProp}
                Slot.Button.Disable()
                
                if (Slot.Type = shelf_type.Museum):
                    set CurrentTickIncome = CurrentTickIncome + ItemToPlace.TickIncome
                    Slot.Billboard.SetText(MakeMuseumItemText(ItemToPlace.ItemName, ItemToPlace.TickIncome))
                else:
                    MinVal := ItemToPlace.SellPrice - 20
                    MaxVal := ItemToPlace.SellPrice + 150
                    Slot.Billboard.SetText(MakeShopItemText(ItemToPlace.ItemName, MinVal, MaxVal))
                UpdateUI()

    OnFixedLootPickedUp(Agent : agent, Loot : loot_definition): void=
        if ((CurrentBackpackWeight + Loot.Weight) <= MaxWeightCapacity):
            
            # --- FELFEDEZÉS MECHANIKA ---
            var IsFirstTime : logic = false
            if (not DiscoveredItems[Loot.ItemName]):
                set IsFirstTime = true
                
            if (IsFirstTime?):
                if (set DiscoveredItems[Loot.ItemName] = true):
                    Logger.Print("Új kincs a Múzeumnak: {Loot.ItemName}")
                    set CurrentPlayerMoney = CurrentPlayerMoney + 1000
                    set StashInventory = StashInventory + array{Loot}
                    if (Player := player[Agent]):
                        spawn{ShowDiscoveryPopup(Player, Loot.ItemName)}
            else:
                set BackpackInventory = BackpackInventory + array{Loot}
            # ---------------------------

            set CurrentBackpackWeight = CurrentBackpackWeight + Loot.Weight
            if (ActualProp := Loot.ItemProp?):
                ActualProp.Hide()
            Loot.PickupButton.Disable()
            set UsedLootDefinitions = UsedLootDefinitions + array{Loot}
            UpdateUI() 
            CheckWeightPenalty(Agent)
        else:
            Logger.Print("Tele a taska!")

    OnPlayerExtracted(Agent : agent): void=
        if (BackpackInventory.Length > 0):
            set StashInventory = StashInventory + BackpackInventory
            set BackpackInventory = array{}
            set CurrentBackpackWeight = 0.0 
            for (Loot : UsedLootDefinitions):
                if (ActualProp := Loot.ItemProp?):
                    ActualProp.Show()
                Loot.PickupButton.Enable()
            set UsedLootDefinitions = array{}
            UpdateUI()
            CheckWeightPenalty(Agent)
        ShopTeleporter.Teleport(Agent)

    OnUpgradeBackpackPressed(Agent : agent): void=
        if (CurrentPlayerMoney >= CurrentUpgradeCost):
            set CurrentPlayerMoney = CurrentPlayerMoney - CurrentUpgradeCost
            set MaxWeightCapacity = MaxWeightCapacity + UpgradeAddedCapacity
            set CurrentUpgradeCost = CurrentUpgradeCost * 2 
            UpdateUI()
            CheckWeightPenalty(Agent)

    OnPaywallPressed(Agent : agent): void=
        if (CurrentPlayerMoney >= PaywallCost):
            set CurrentPlayerMoney = CurrentPlayerMoney - PaywallCost
            for (Wall : PaywallProps):
                Wall.Dispose()
            PaywallButton.Disable() 
            UpdateUI()

    CheckWeightPenalty(Agent : agent): void=
        if (Player := player[Agent]):
            ApplyWeightPenalty(Player, CurrentBackpackWeight)

    DropItemFromInventory(IndexToRemove : int, Player : player) : void=
        var NewInventory : []loot_definition = array{}
        var DroppedWeight : float = 0.0
        for (Index -> Item : BackpackInventory):
            if (Index = IndexToRemove):
                set DroppedWeight = Item.Weight
            else:
                set NewInventory = NewInventory + array{Item}

        set BackpackInventory = NewInventory
        set CurrentBackpackWeight = CurrentBackpackWeight - DroppedWeight
        if (CurrentBackpackWeight < 0.1):
            set CurrentBackpackWeight = 0.0
        UpdateUI()
        ApplyWeightPenalty(Player, CurrentBackpackWeight)

    UpdateUI(): void=
        for (Player : GetPlayspace().GetPlayers(), PlayerUI := GetPlayerUI[Player]):
            if (OldCanvas := CurrentCanvas?):
                PlayerUI.RemoveWidget(OldCanvas)
            
            MoneyUI.SetText(MakeMoneyText(CurrentPlayerMoney))
            WeightUI.SetText(MakeWeightText(CurrentBackpackWeight, MaxWeightCapacity))
            StashUI.SetText(MakeStashText(StashInventory.Length, CurrentTickIncome))

            var UIWidgets : []stack_box_slot = array{}
            for (Index -> Item : BackpackInventory):
                DropButton := button_loud{DefaultText := MakeDropText(Item.ItemName, Item.Weight)}
                Handler := drop_item_handler{Manager := Self, ItemIndex := Index}
                DropButton.OnClick().Subscribe(Handler.OnClick)
                set UIWidgets = UIWidgets + array:
                    stack_box_slot{Widget := DropButton, Padding := margin{Top := 5.0, Bottom := 5.0}}
            
            NewInventoryUIBox := stack_box{Orientation := orientation.Vertical, Slots := UIWidgets}

            NewCanvas := canvas:
                Slots := array:
                    canvas_slot:
                        Anchors := anchors{Minimum := vector2{X := 0.05, Y := 0.20}, Maximum := vector2{X := 0.05, Y := 0.20}}
                        Widget := MoneyUI
                    canvas_slot:
                        Anchors := anchors{Minimum := vector2{X := 0.05, Y := 0.25}, Maximum := vector2{X := 0.05, Y := 0.25}}
                        Widget := WeightUI
                    canvas_slot:
                        Anchors := anchors{Minimum := vector2{X := 0.05, Y := 0.30}, Maximum := vector2{X := 0.05, Y := 0.30}}
                        Widget := StashUI
                    canvas_slot:
                        Anchors := anchors{Minimum := vector2{X := 0.80, Y := 0.30}, Maximum := vector2{X := 0.80, Y := 0.30}}
                        Alignment := vector2{X := 0.0, Y := 0.0}
                        Widget := NewInventoryUIBox
            
            set CurrentCanvas = option{NewCanvas}
            PlayerUI.AddWidget(NewCanvas)

    CreatePlayerUI(Player : player): void=
        UpdateUI()

    ApplyWeightPenalty(Player : player, TotalWeight : float) : void =
        if (FortChar := Player.GetFortCharacter[]):
            var WeightRatio : float = TotalWeight / MaxWeightCapacity
            var TargetTier : int = 0
            if (WeightRatio >= 0.25 and WeightRatio < 0.50):
                set TargetTier = 1 
            else if (WeightRatio >= 0.50 and WeightRatio < 0.75):
                set TargetTier = 2 
            else if (WeightRatio >= 0.75):
                set TargetTier = 3 
            else:
                set TargetTier = 0 

            var CurrentTier : int = 0
            if (SavedTier := PlayerWeightTiers[Player]):
                set CurrentTier = SavedTier

            if (TargetTier <> CurrentTier):
                if (set PlayerWeightTiers[Player] = TargetTier):
                    if (TargetTier >= 0 and TargetTier < ClassSelectors.Length, TargetSelector := ClassSelectors[TargetTier]):
                        TargetSelector.ChangeClass(Player)
                        Logger.Print("Súlybüntetés frissítve: {TargetTier}. szint")

    # --- FILMES FELFEDEZÉS POPUP ANIMÁCIÓ ---
    ShowDiscoveryPopup(Player : player, ItemName : string)<suspends> : void=
        if (PlayerUI := GetPlayerUI[Player]):
            DarkBackground := color_block{DefaultColor := NamedColors.Black, DefaultOpacity := 0.8, DefaultDesiredSize := vector2{X := 3000.0, Y := 3000.0}}
            TitleText := text_block{DefaultText := MakeDiscoveryTitleText(), DefaultTextColor := NamedColors.Yellow}
            NameText := text_block{DefaultText := MakeDiscoveryItemText(ItemName), DefaultTextColor := NamedColors.White}
            
            PopupCanvas := canvas:
                Slots := array:
                    canvas_slot:
                        Widget := DarkBackground
                        Anchors := anchors{Minimum := vector2{X:=0.0, Y:=0.0}, Maximum := vector2{X:=1.0, Y:=1.0}}
                    canvas_slot:
                        Widget := TitleText
                        Anchors := anchors{Minimum := vector2{X:=0.5, Y:=0.4}, Maximum := vector2{X:=0.5, Y:=0.4}}
                        Alignment := vector2{X:=0.5, Y:=0.5}
                    canvas_slot:
                        Widget := NameText
                        Anchors := anchors{Minimum := vector2{X:=0.5, Y:=0.5}, Maximum := vector2{X:=0.5, Y:=0.5}}
                        Alignment := vector2{X:=0.5, Y:=0.5}

            PlayerUI.AddWidget(PopupCanvas)
            Sleep(4.0) 
            PlayerUI.RemoveWidget(PopupCanvas)