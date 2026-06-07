using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }

loot_definition := class<concrete><public>:
    @editable ItemName : string = "Ismeretlen Tárgy"
    @editable ItemAsset : ?creative_prop_asset = false
    @editable ItemProp : ?creative_prop = false
    @editable PickupButton : button_device = button_device{}
    @editable Weight : float = 5.0
    @editable SellPrice : int = 50
    @editable TickIncome : int = 5

shelf_type := enum<public>{ Shop, Museum }

MakeMoneyText<localizes><public>(MoneyValue : int) : message = "PÉNZ: {MoneyValue} $"
MakeWeightText<localizes><public>(WeightValue : float, MaxWeight : float) : message = "SÚLY: {WeightValue} / {MaxWeight} kg"
MakeStashText<localizes><public>(StashValue : int, TickIncome : int) : message = "RAKTÁR: {StashValue} db | MÚZEUM: +{TickIncome} $/tick"
MakeDropText<localizes><public>(Name: string, Weight: float) : message = "ELDOBÁS: {Name} ({Weight} kg)"
MakeEmptyShelfText<localizes><public>() : message = "[ ÜRES POLC ]\nKattints a kipakoláshoz"
MakeShopItemText<localizes><public>(Name: string, MinPrice: int, MaxPrice: int) : message = "{Name}\nBecsült érték:\n{MinPrice} $ - {MaxPrice} $\n(Vevőre vár)"
MakeMuseumItemText<localizes><public>(Name: string, Income: int) : message = "MÚZEUM: {Name}\nKiállítva\nBevétel: +{Income} $/tick"
MakeNPCGreetingText<localizes><public>() : message = "[ PULT ]\nKattints az alkudozás indításához."
MakeNPCOfferText<localizes><public>(ItemName: string, Offer: int) : message = "NPC Vevő: Látom kint van a {ItemName}.\nAdok érte {Offer} $-t!\nMit lépsz?"
MakeNPCNoItemsText<localizes><public>() : message = "NPC Vevő: Nincs semmi a bolti polcokon, ami érdekelne."
MakeDiscoveryTitleText<localizes><public>() : message = "ÚJ FELFEDEZÉS!"
MakeDiscoveryItemText<localizes><public>(ItemName : string) : message = "{ItemName}"

# --- ÚJ: Batch Sell Szövegek ---
MakeCategoryText<localizes><public>(Title : string) : message = "=== {Title} ==="
MakeGroupedItemText<localizes><public>(Name: string, Count: int, TotalValue: int) : message = "{Name} | {Count} db | Érték: {TotalValue} $"
MakeSellBtnText<localizes><public>(AmountStr: string) : message = "ELAD ({AmountStr})"
MakeToggleModeText<localizes><public>(CurrentMode: string) : message = "Eladási Mód: [ {CurrentMode} ]"
MakeSellAllText<localizes><public>(TotalValue: int) : message = "MINDENT ELAD (+{TotalValue} $)"