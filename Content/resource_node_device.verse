using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }

resource_node_device := class(creative_device):

    @editable MineButton : button_device = button_device{}
    @editable NodeName : string = "Vasérc"
    @editable NodeWeight : float = 5.0
    @editable NodePrice : int = 50
    @editable RespawnTime : float = 60.0 
    @editable NodeMesh : prop_manipulator_device = prop_manipulator_device{}

    OnBegin<override>()<suspends>:void=
        MineButton.InteractedWithEvent.Subscribe(OnMined)

    OnMined(Agent : agent):void=
        Print("{NodeName} kibányászva! Súly: {NodeWeight} kg, Érték: {NodePrice} $")
        
        var MinedLoot : loot_definition = loot_definition{
            ItemName := NodeName,
            Weight := NodeWeight,
            SellPrice := NodePrice,
            ItemAsset := false,
            ItemProp := false,
            PickupButton := button_device{}
        }
        
        MineButton.Disable()
        NodeMesh.HideProps()
        spawn{RespawnTimer()}

    RespawnTimer()<suspends>:void=
        Sleep(RespawnTime)
        NodeMesh.ShowProps()
        MineButton.Enable()