using { /Verse.org/Simulation }
using { /Verse.org/Random }

# Az NPC döntéshozó központja
pawn_npc_brain := class<public>():
    
    CalculateNPCOffer<public>(BasePrice: int, RebirthLevel: int): int =
        var MinMultiplier : float = 0.8
        var MaxMultiplier : float = 1.5 + (RebirthLevel * 0.5)
        var RandomFactor : float = GetRandomFloat(MinMultiplier, MaxMultiplier)
        var FinalOfferFloat : float = (BasePrice * 1.0) * RandomFactor
        return Floor[FinalOfferFloat] or BasePrice

    PlayNPCDecisionAnimation<public>(BasePrice: int, FinalOffer: int): void =
        var OfferRatio: float = (FinalOffer * 1.0) / (BasePrice * 1.0)
        if (OfferRatio < 0.9):
            Print("NPC Vizuális Reakció: Flegma legyintés.")
        else if (OfferRatio >= 0.9 and OfferRatio <= 1.5):
            Print("NPC Vizuális Reakció: Gondolkodó bólogatás.")
        else:
            Print("NPC Vizuális Reakció: Izgatott gesztikuláció.")