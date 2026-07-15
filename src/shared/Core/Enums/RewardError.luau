--!strict
-- RewardError.luau
-- Defines error codes for the reward pipeline.
return table.freeze({
	PersistenceFailed = "PersistenceFailed",
	DuplicateTransaction = "DuplicateTransaction",
	InvalidPayload = "InvalidPayload",
	DispatcherFailed = "DispatcherFailed",
	UnknownReward = "UnknownReward",
})
