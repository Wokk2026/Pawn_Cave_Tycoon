using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }

resource_node_device := class(creative_device):

    # Az interakciós gomb a sziklán
    @editable MineButton : button_device = button_device{}
    
    # Beállíthatod az UEFN Details panelen, hogy ez a kő Vasat, Rezet vagy Gyémántot adjon
    @editable NodeName : string = "Vasérc"
    @editable NodeWeight : float = 5.0
    @editable NodePrice : int = 50
    @editable RespawnTime : float = 60.0 # Másodpercben
    @editable NodeMesh : prop_manipulator_device = prop_manipulator_device{} # A szikla elrejtéséhez

    OnBegin<override>()<suspends>:void=
        # Feliratkozunk a gombnyomásra
        MineButton.InteractedWithEvent.Subscribe(OnMined)

   OnMined(Agent : agent):void=
        # ... (a loot generálás marad a régi) ...
        
        MineButton.Disable()
        NodeMesh.HideProps() # Eltüntetjük a sziklát
        
        # Elindítjuk az újraéledési időzítőt a háttérben
        spawn{RespawnTimer()}
        
        # 1. Itt gyártjuk le a lootot
        var MinedLoot : loot_definition = loot_definition{
            ItemName := NodeName,
            Weight := NodeWeight,
            SellPrice := NodePrice,
            ItemAsset := false,
            ItemProp := false,
            PickupButton := button_device{}
        }
        
        # 2. Itt fogjuk átküldeni a táska (Inventory) menedzsernek
        # (A holnapi összekötésnél ide írjuk a hívást)
        RespawnTimer()<suspends>:void=
        Sleep(RespawnTime)
        NodeMesh.ShowProps()
        MineButton.Enable()
        # 3. Kikapcsoljuk a gombot, hogy ne lehessen végtelenül bányászni ugyanazt a követ
        MineButton.Disable()