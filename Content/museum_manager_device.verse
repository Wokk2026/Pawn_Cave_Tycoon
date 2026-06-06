using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }

museum_manager_device := class(creative_device):

    # Milyen gyakran ketyegjen a passzív bevétel (másodperc)
    @editable TickRate : float = 5.0 
    
    # Később ide kötjük be a pénzadó eszközt (Item Granter)
    @editable MoneyGranter : item_granter_device = item_granter_device{}

    # A vitrinekbe helyezett kincsek listája
    var ActiveMuseumItems : []loot_definition = array{}

    OnBegin<override>()<suspends>:void=
        Print("Múzeum rendszer elindítva. Passzív hurok aktív.")
        # Elindítunk egy párhuzamos szálat, ami a háttérben fut a játék végéig
        spawn{PassiveIncomeLoop()}

    # A profik így csinálják a Tycoon tick-eket:
    PassiveIncomeLoop()<suspends>:void=
        loop:
            Sleep(TickRate)
            var TotalIncome : int = 0
            
            # Végigmegyünk a kiállított tárgyakon, és összeadjuk az értéküket
            for (Item : ActiveMuseumItems):
                set TotalIncome += Item.SellPrice 
            
            if (TotalIncome > 0):
                # Ide jön a kód, ami fizikailag hozzáadja a pénzt a játékoshoz
                Print("Múzeum passzív bevétel: +{TotalIncome} $ / tick")