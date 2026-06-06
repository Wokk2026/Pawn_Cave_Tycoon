using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }

# Elérhetővé tesszük a saját projekt névterünket, hogy a fordító lássa a loot_definition-t
using { /localhost/Pawn_Cave_Tycoon } 

# Egyedi azonosító a nyersanyagok típusainak elkülönítésére
raw_material_type := enum{ IronOre, CopperOre, GoldOre, RefinedMetal }

# Egyetlen hozzávaló leírása
recipe_ingredient := struct<concrete>:
    MaterialType : raw_material_type = raw_material_type.IronOre
    Amount : int = 1

# A teljes recept struktúrája
crafting_recipe := struct<concrete>:
    Ingredients : []recipe_ingredient = array{}
    ResultType : raw_material_type = raw_material_type.RefinedMetal
    ResultWeight : float = 5.0
    ResultBasePrice : int = 150

craft_station_validator := class(creative_device):

    # JAVÍTÁS: A 'tuple' kulcsszó törölve a visszatérési típusból, csak a zárójel () maradt!
    ValidateAndCraft(CurrentInventory: []loot_definition, Recipe: crafting_recipe, CurrentWeightCapacity: float, CurrentBackpackWeight: float):?([]loot_definition, loot_definition) =
        
        # Ide gyűjtjük azokat az indexeket, amiket a sikeres crafting során ki kell hagyni a táskából
        var IndicesToRemove : []int = array{}
        var MissingIngredients : logic = false

        for (Ingredient : Recipe.Ingredients):
            var FoundCount : int = 0
            var TrackedIndices : []int = array{}

            for (Index -> Item : CurrentInventory):
                if (CheckItemType(Item, Ingredient.MaterialType)?):
                    set FoundCount = FoundCount + 1
                    set TrackedIndices = TrackedIndices + array{Index}

            if (FoundCount >= Ingredient.Amount):
                # Csak annyi indexet veszünk el, amennyi a recepthez kell
                if (ValidIndices := TrackedIndices.Slice[0, Ingredient.Amount]):
                    set IndicesToRemove = IndicesToRemove + ValidIndices
            else:
                set MissingIngredients = true

        # Ha bármi hiányzik, azonnal leállunk
        if (MissingIngredients?):
            return false

        # Súlykontroll ellenőrzése
        var FlippedWeight : float = 0.0
        for (Idx : IndicesToRemove):
            if (Item := CurrentInventory[Idx]):
                set FlippedWeight = FlippedWeight + Item.Weight

        FinalEstimatedWeight := CurrentBackpackWeight - FlippedWeight + Recipe.ResultWeight
        if (FinalEstimatedWeight > CurrentWeightCapacity):
            return false

        # Új inventory összefésülése biztonságos ciklussal
        var NewInventory : []loot_definition = array{}
        for (Index -> Item : CurrentInventory):
            var ShouldRemove : logic = false
            for (RemoveIdx : IndicesToRemove):
                if (Index = RemoveIdx):
                    set ShouldRemove = true
            
            if (not ShouldRemove?):
                set NewInventory = NewInventory + array{Item}

        # A jutalom legyártása
        CraftedItem := loot_definition:
            ItemName := "Finomított Fém"
            Weight := Recipe.ResultWeight
            SellPrice := Recipe.ResultBasePrice
            ItemAsset := false
            ItemProp := false
            PickupButton := button_device{}[cite: 1]

        # Szigorú Verse tuple visszatérési érték (kulcsszó nélkül)
        return option{(NewInventory + array{CraftedItem}, CraftedItem)}

    # Segédfüggvény a tárgytípusok név alapján történő ellenőrzésére
    CheckItemType(Item: loot_definition, TargetType: raw_material_type):?logic =
        if (TargetType = raw_material_type.IronOre and Item.ItemName = "Vasérc"):
            return option{true}
        if (TargetType = raw_material_type.CopperOre and Item.ItemName = "Rézérc"):
            return option{true}
        if (TargetType = raw_material_type.GoldOre and Item.ItemName = "Aranyérc"):
            return option{true}
        return false