using { /Fortnite.com/Devices }
using { /Fortnite.com/Characters }
using { /Fortnite.com/UI }
using { /Verse.org/Simulation }
using { /Verse.org/Colors }
using { /Verse.org/Random }
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /UnrealEngine.com/Temporary/UI }
using { /UnrealEngine.com/Temporary/SpatialMath }

log_pawn_shop := class(log_channel){}

MakeMoneyText<localizes>(MoneyValue : int) : message = "PÉNZ: {MoneyValue} $"
MakeWeightText<localizes>(WeightValue : float, MaxWeight : float) : message = "SÚLY: {WeightValue} / {MaxWeight} kg"
MakeStashText<localizes>(StashValue : int, TickIncome : int) : message = "RAKTÁR: {StashValue} db | MÚZEUM: +{TickIncome} $/tick"
MakeDropText<localizes>(Name: string, Weight: float) : message = "ELDOBÁS: {Name} ({Weight} kg)"
MakeEmptyShelfText<localizes>() : message = "[ ÜRES POLC ]\nKattints a kipakoláshoz"
MakeShopItemText<localizes>(Name: string, MinPrice: int, MaxPrice: int) : message = "{Name}\nBecsült érték:\n{MinPrice} $ - {MaxPrice} $\n(Vevőre vár)"
MakeMuseumItemText<localizes>(Name: string, Income: int) : message = "MÚZEUM: {Name}\nKiállítva\nBevétel: +{Income} $/tick"
MakeNPCGreetingText<localizes>() : message = "[ PULT ]\nKattints az alkudozás indításához."
MakeNPCOfferText<localizes>(ItemName: string, Offer: int) : message = "NPC Vevő: Látom kint van a {ItemName}.\nAdok érte {Offer} $-t!\nMit lépsz?"
MakeNPCNoItemsText<localizes>() : message = "NPC Vevő: Nincs semmi a bolti polcokon, ami érdekelne."

drop_item_handler := class():
    Manager : pawn_shop_manager_device
    ItemIndex : int
    
    OnClick(Message : widget_message):void=
        Manager.DropItemFromInventory(ItemIndex, Message.Player)

loot_definition := class<concrete><public>:
    @editable ItemName : string = "Ismeretlen Tárgy"
    @editable ItemAsset : ?creative_prop_asset = false
    @editable ItemProp : ?creative_prop = false
    @editable PickupButton : button_device = button_device{}
    @editable Weight : float = 5.0
    @editable SellPrice : int = 50
    @editable TickIncome : int = 5

shelf_type := enum{ Shop, Museum }

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
    var PlayerWeightTiers : [player]int = map{}

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
    # ÚJ: Ez tárolja, hogy mit fedeztünk már fel a játék során
    var DiscoveredItems : [string]logic = map{}
    var StashInventory : []loot_definition = array{}

    var MoneyUI : text_block = text_block{DefaultTextColor := NamedColors.White}
    var WeightUI : text_block = text_block{DefaultTextColor := NamedColors.White}
    var StashUI : text_block = text_block{DefaultTextColor := NamedColors.Yellow}
    var InventoryUIBox : stack_box = stack_box{Orientation := orientation.Vertical}
    var CurrentCanvas : ?canvas = false

    OnBegin<override>()<suspends>: void=
        set CurrentPlayerMoney = StartingMoney
        set CurrentUpgradeCost = BaseUpgradeCost
        
        for (Index -> Marker : ShopShelfMarkers):
            if (Button := ShopShelfButtons[Index], Billboard := ShopShelfBillboards[Index]):
                Slot := shelf_slot{Index := Index, ShelfMarker := Marker, Button := Button, Billboard := Billboard, Type := shelf_type.Shop, Manager := Self}
                Slot.Init()
                set ShopShelves = ShopShelves + array{Slot}

        for (Index -> Marker : MuseumShelfMarkers):
            if (Button := MuseumShelfButtons[Index], Billboard := MuseumShelfBillboards[Index]):
                Slot := shelf_slot{Index := Index, ShelfMarker := Marker, Button := Button, Billboard := Billboard, Type := shelf_type.Museum, Manager := Self}
                Slot.Init()
                set MuseumShelves = MuseumShelves + array{Slot}

        for (LootDef : LootDatabase):
            LootSource := fixed_loot_source{LootData := LootDef, Manager := Self}
            LootSource.Init()
        
        Playspace := GetPlayspace()
        for (Player : Playspace.GetPlayers()):
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
        for (Slot : ShopShelves):
            if (not Slot.IsEmpty?):
                set FullShelves = FullShelves + array{Slot}

        if (FullShelves.Length > 0):
            RandomShelfIndex := GetRandomInt(0, FullShelves.Length - 1)
            if (TargetShelf := FullShelves[RandomShelfIndex], Loot := TargetShelf.PlacedLoot?):
                FinalOffer := CalculateNPCOffer(Loot.SellPrice, CurrentRebirthLevel)
                PlayNPCDecisionAnimation(Loot.SellPrice, FinalOffer)
                
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
                
            if (not Slot.IsEmpty?, IsNegotiated = 0):
                if (Loot := Slot.PlacedLoot?, Prop := Slot.PlacedProp?):
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
            Logger.Print("Kassza: Szabad bolti tárgyak eladva alapáron!")
        else:
            Logger.Print("Uresek a bolti polcok, vagy épp mindről alkudozol!")

    OnShelfPlaceAttempt(Agent : agent, Slot : shelf_slot):void=
        if (StashInventory.Length > 0):
            LastIndex := StashInventory.Length - 1
            if (ItemToPlace := StashInventory[LastIndex]):
                MarkerTransform := Slot.ShelfMarker.GetTransform()
                CorrectedTransform := transform:
                    Translation := MarkerTransform.Translation
                    Rotation := MarkerTransform.Rotation
                    Scale := vector3{X := 1.0, Y := 1.0, Z := 1.0}
               
                if (ActualAsset := ItemToPlace.ItemAsset?):
                    SpawnResult := SpawnProp(ActualAsset, CorrectedTransform)
                    
                    if (SpawnedProp := SpawnResult(0)?):
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
            var IsFirstTime : logic = false
            if (not DiscoveredItems[Loot.ItemName]):
                set IsFirstTime = true
            set BackpackInventory = BackpackInventory + array{Loot}
            set CurrentBackpackWeight = CurrentBackpackWeight + Loot.Weight
            if (ActualProp := Loot.ItemProp?):
                ActualProp.Hide()
            Loot.PickupButton.Disable()
            if (IsFirstTime?):
                # Életében először vette fel!
                if (set DiscoveredItems[Loot.ItemName] = true):
                    Logger.Print("ÚJ FELFEDEZÉS: {Loot.ItemName}! Ez a Múzeumba megy, nem adhatod el.")
                    # Itt adhatunk bónusz pénzt a felfedezésért
                    set CurrentPlayerMoney = CurrentPlayerMoney + 1000
            set UsedLootDefinitions = UsedLootDefinitions + array{Loot}
            UpdateUI() 
            CheckWeightPenalty(Agent)
            if (IsFirstTime?):
                # Életében először vette fel!
                if (set DiscoveredItems[Loot.ItemName] = true):
                    Logger.Print("ÚJ FELFEDEZÉS: {Loot.ItemName}! Ez a Múzeumba megy, nem adhatod el.")
                    # Itt adhatunk bónusz pénzt a felfedezésért
                    set CurrentPlayerMoney = CurrentPlayerMoney + 1000
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
        else:
            Logger.Print("Nincs eleg penzed a fejlesztesre!")

    OnPaywallPressed(Agent : agent): void=
        if (CurrentPlayerMoney >= PaywallCost):
            set CurrentPlayerMoney = CurrentPlayerMoney - PaywallCost
            for (Wall : PaywallProps):
                Wall.Dispose()
            PaywallButton.Disable() 
            UpdateUI()
        else:
            Logger.Print("Nincs eleg penzed az ajto kinyitasara!")

    CheckWeightPenalty(Agent : agent): void=
        if (Player := player[Agent]):
            ApplyWeightPenalty(Player, CurrentBackpackWeight)

    UpdateUI(): void=
        Playspace := GetPlayspace()
        for (Player : Playspace.GetPlayers(), PlayerUI := GetPlayerUI[Player]):
            # Letöröljük a régi UI-t, ha volt
            if (OldCanvas := CurrentCanvas?):
                PlayerUI.RemoveWidget(OldCanvas)
            
            MoneyUI.SetText(MakeMoneyText(CurrentPlayerMoney))
            WeightUI.SetText(MakeWeightText(CurrentBackpackWeight, MaxWeightCapacity))
            StashUI.SetText(MakeStashText(StashInventory.Length, CurrentTickIncome))

            # Legyártjuk az új gombokat
            var UIWidgets : []stack_box_slot = array{}
            for (Index -> Item : BackpackInventory):
                DropButton := button_loud{DefaultText := MakeDropText(Item.ItemName, Item.Weight)}
                Handler := drop_item_handler{Manager := Self, ItemIndex := Index}
                DropButton.OnClick().Subscribe(Handler.OnClick)
                set UIWidgets = UIWidgets + array:
                    stack_box_slot{Widget := DropButton, Padding := margin{Top := 5.0, Bottom := 5.0}}
            
            NewInventoryUIBox := stack_box{Orientation := orientation.Vertical, Slots := UIWidgets}

            # Felépítjük a friss vásznat
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
                    ExecuteClassChange(Player, TargetTier)
                    Logger.Print("Súlybüntetés frissítve. Játékos új szintje: {TargetTier}")

    ExecuteClassChange(Player : player, TierIndex : int) : void =
        if (TierIndex >= 0 and TierIndex < ClassSelectors.Length):
            if (TargetSelector := ClassSelectors[TierIndex]):
                TargetSelector.ChangeClass(Player)

    CalculateNPCOffer(BasePrice: int, RebirthLevel: int): int =
        var MinMultiplier : float = 0.8
        var MaxMultiplier : float = 1.5 + (RebirthLevel * 0.5)
        var RandomFactor : float = GetRandomFloat(MinMultiplier, MaxMultiplier)
        var FinalOfferFloat : float = (BasePrice * 1.0) * RandomFactor
        var FinalOffer : int = Floor[FinalOfferFloat] or BasePrice
        return FinalOffer
        
    DropItemFromInventory(IndexToRemove : int, Player : player) : void=
        var NewInventory : []loot_definition = array{}
        var DroppedWeight : float = 0.0

        for (Index -> Item : BackpackInventory):
            if (Index = IndexToRemove):
                set DroppedWeight = Item.Weight
                Logger.Print("Tárgy eldobva: {Item.ItemName}")
            else:
                set NewInventory = NewInventory + array{Item}

        set BackpackInventory = NewInventory
        set CurrentBackpackWeight = CurrentBackpackWeight - DroppedWeight
        
        if (CurrentBackpackWeight < 0.1):
            set CurrentBackpackWeight = 0.0
            
        UpdateUI()
        ApplyWeightPenalty(Player, CurrentBackpackWeight)

    PlayNPCDecisionAnimation(BasePrice: int, FinalOffer: int): void =
        var OfferRatio: float = (FinalOffer * 1.0) / (BasePrice * 1.0)
        
        if (OfferRatio < 0.9):
            Logger.Print("NPC Vizuális Reakció: Flegma legyintés. Pocsék ajánlat.")
        else if (OfferRatio >= 0.9 and OfferRatio <= 1.5):
            Logger.Print("NPC Vizuális Reakció: Gondolkodó bólogatás. Megfontolt ajánlat.")
        else:
            Logger.Print("NPC Vizuális Reakció: Izgatott gesztikuláció. Jackpot ajánlat!")