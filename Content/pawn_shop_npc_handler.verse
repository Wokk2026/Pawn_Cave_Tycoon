using { /Verse.org/Simulation }
using { /Verse.org/Random }
using { /Verse.org/Colors }

# Ezt a függvényt a pawn_shop_npc_handler osztályodon belülre helyezd
CalculateNPCOffer(BasePrice: int, RebirthLevel: int): int =
    
    # A minimum szorzó fixen kemény marad minden szinten: az NPC akár 20%-kal az alapár alá is mehet.
    var MinMultiplier : float = 0.8
    
    # A maximum szorzó a Kaszinó modell szerint drasztikusan nő.
    # Rebirth 0: max 1.5x (+50%)
    # Rebirth 1: max 2.0x (+100%)
    # Rebirth 5: max 4.0x (+300%)
    var MaxMultiplier : float = 1.5 + (RebirthLevel * 0.5)
    
    # A sorsolás: a gép választ egy véletlen szorzót a két véglet között.
    var RandomFactor : float = GetRandomFloat(MinMultiplier, MaxMultiplier)
    
    # A végleges ár kiszámítása. 
    # Mivel a RandomFactor float (tört), a BasePrice pedig int (egész), először át kell alakítanunk.
    var FinalOfferFloat : float = (BasePrice * 1.0) * RandomFactor
    
    # Visszakerekítjük egész számra a Floor (lefelé kerekítés) vagy Ceil (felfelé kerekítés) segítségével.
    # Ha a konverzió valamiért elbukna, a fallback (or) az alapárat adja vissza.
    var FinalOffer : int = Floor[FinalOfferFloat] or BasePrice
    
    return FinalOffer