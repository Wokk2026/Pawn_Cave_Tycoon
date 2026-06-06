using { /Fortnite.com/Devices }
using { /Fortnite.com/Characters }
using { /Verse.org/Simulation }

# A teljes, multiplayer-kompatibilis Weight Manager eszköz
PawnCave_WeightManager := class(creative_device):

    # Az UEFN-ben ide húzod be a 4 darab Class Selectort, szigorúan sorrendben (Könnyű -> Túlterhelt)
    @editable
    ClassSelectors : []class_selector_device = array{}

    # TÖBBJÁTÉKOS VÉDELEM: Ez a map (szótár) tárolja el játékosokra lebontva, hogy ki melyik szinten van
    var PlayerWeightTiers : [player]int = map{}

    OnBegin<override>()<suspends>: void =
        # Itt inicializálódik az eszköz a játék indulásakor
        Print("PawnCave_WeightManager elindult. A 4-lépcsős Class-alapú súlyrendszer aktív.")

    # Ezt a publikus függvényt hívhatod meg a Tappable HUD-ból vagy az Inventory logikából, amikor egy tárgyat felvesznek/leraknak
    public ApplyWeightPenalty(Player : player, TotalWeight : float) : void =
        if (FortChar := Player.GetFortCharacter[]):
            
            # 1. LÉPÉS: Határértékek kiszámítása a GDD alapján (v41.00)
            var TargetTier : int = 0
            if (TotalWeight >= 25.0 and TotalWeight < 50.0):
                set TargetTier = 1 # Közepes (20% lassulás)
            else if (TotalWeight >= 50.0 and TotalWeight < 75.0):
                set TargetTier = 2 # Nehéz (50% lassulás, Sprintelés tiltva)
            else if (TotalWeight >= 75.0):
                set TargetTier = 3 # Túlterhelt (90% lassulás, Sprintelés tiltva)
            else:
                set TargetTier = 0 # Könnyű (Alapértelmezett, 100% sebesség)

            # 2. LÉPÉS: Lekérdezzük a játékos JELENLEGI szintjét a Map-ből
            var CurrentTier : int = 0
            if (SavedTier := PlayerWeightTiers[Player]):
                set CurrentTier = SavedTier

            # 3. LÉPÉS: Csak akkor terheljük a szervert osztályváltással, ha TÉNYLEG szintet lépett
            if (TargetTier /= CurrentTier):
                # Frissítjük a játékos rekordját a Map-ben
                if (set PlayerWeightTiers[Player] = TargetTier):
                    # Végrehajtjuk a tényleges váltást
                    ExecuteClassChange(Player, TargetTier)
                    Print("Súlybüntetés frissítve. Játékos új szintje: {TargetTier}")

    # Privát függvény: A tényleges eszközaktiválás
    ExecuteClassChange(Player : player, TierIndex : int) : void =
        # Hibatűrő vizsgálat: Megnézzük, hogy létezik-e egyáltalán az adott sorszámú Selector a tömbben
        if (TierIndex >= 0 and TierIndex < ClassSelectors.Length):
            if (TargetSelector := ClassSelectors[TierIndex]):
                # A ChangeClass a stabil, beépített metódus az osztály módosítására
                TargetSelector.ChangeClass(Player)