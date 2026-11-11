-- Eventos locais do cliente entre scripts.

local MotoSignals = {}

MotoSignals.Bump = Instance.new("BindableEvent")
MotoSignals.FlatTire = Instance.new("BindableEvent")
MotoSignals.Hazard = Instance.new("BindableEvent")
-- (tipo, intensidade 0..1): o que de fato aconteceu com a moto, para o som e o HUD
MotoSignals.Impact = Instance.new("BindableEvent")

return MotoSignals
