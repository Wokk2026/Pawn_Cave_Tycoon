using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /Verse.org/Random }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Verse.org/SceneGraph }

pawn_shop_npc_handler := class(creative_device):

    # --- Scene Graph Tulajdonságok ---
    @editable NPCPrefab : prefab = prefab{}
    @editable NPCSpawnPoint : transform = transform{}

    var CurrentNPCEntity : ?entity = false

    # --- Matematikai és Gazdasági Logika ---
    # Ezt a függvényt hívja majd meg a manager az alkudozás indításakor
    CalculateOfferRange(BasePrice : int, RebirthLevel : int) : tuple(int, int) =
        MinPercentage : int = 80 + (RebirthLevel * 5)
        MaxPercentage : int = 120 + (RebirthLevel * 10)

        var MinOffer : int = BasePrice
        var MaxOffer : int = BasePrice

        # A Verse-ben az osztás (/) 'decides' effektű, ezért if-be kell csomagolni
        if:
            TempMin := (BasePrice * MinPercentage) / 100
            TempMax := (BasePrice * MaxPercentage) / 100
        then:
            set MinOffer = TempMin
            set MaxOffer = TempMax

        if (MinOffer > MaxOffer):
            return (MaxOffer, MinOffer)
        else:
            return (MinOffer, MaxOffer)

    # --- NPC Vizuális Kezelése (Scene Graph) ---
    SpawnNPCBuyer()<suspends>: void =
        # 1. Tisztítás: Ha már van bent entitás, töröljük (memória szivárgás elkerülése)
        DespawnNPCBuyer()

        # 2. Új Scene Graph Entitás példányosítása a megadott ponton
        if (SpawnedEntity := NPCPrefab.Spawn(NPCSpawnPoint)?):
            set CurrentNPCEntity = option{SpawnedEntity}
            # Profi tipp: Ide köthetsz egy részecske-effektet (VFX) vagy egy hangeffektet az entitás megjelenésekor.
            
    DespawnNPCBuyer(): void =
        if (EntityToRemove := CurrentNPCEntity?):
            EntityToRemove.Dispose()
            set CurrentNPCEntity = false

    # --- Integrációs teszt függvény ---
    TestNegotiation(LootPrice : int, RebirthLvl : int): void =
        Range := CalculateOfferRange(LootPrice, RebirthLvl)
        # Az értékek szétbontása a tuple-ből
        MinVal := Range(0)
        MaxVal := Range(1)
        
        FinalOffer := GetRandomInt(MinVal, MaxVal)
        Print("Új NPC Ajánlat: {FinalOffer} $ (Rebirth: {RebirthLvl})")