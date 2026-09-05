--!strict
-- DailyRewardConfig.luau
-- Authoritative configuration for the 7-day Daily Login Rewards system.

local RewardType = {
	Bigger = "Bigger",
	Destruction = "Destruction",
	SpinTokens = "SpinTokens",
	Trail = "Trail",
	Title = "Title",
}

export type DailyReward = {
	Day: number,
	Name: string,
	Reward: {
		Type: string,
		Amount: number?,
		Id: string?,
		[string]: any,
	},
}

local DailyRewardConfig = {}

DailyRewardConfig.CooldownSeconds = 86400
DailyRewardConfig.CooldownInterval = 86400

DailyRewardConfig.Days = {
	[1] = {
		Day = 1,
		Name = "1,000 Bigger",
		Reward = { Type = RewardType.Bigger, Amount = 1000 },
	},
	[2] = {
		Day = 2,
		Name = "25 Destruction",
		Reward = { Type = RewardType.Destruction, Amount = 25 },
	},
	[3] = {
		Day = 3,
		Name = "2 Spin Tokens",
		Reward = { Type = RewardType.SpinTokens, Amount = 2 },
	},
	[4] = {
		Day = 4,
		Name = "5,000 Bigger",
		Reward = { Type = RewardType.Bigger, Amount = 5000 },
	},
	[5] = {
		Day = 5,
		Name = "100 Destruction",
		Reward = { Type = RewardType.Destruction, Amount = 100 },
	},
	[6] = {
		Day = 6,
		Name = "5 Spin Tokens",
		Reward = { Type = RewardType.SpinTokens, Amount = 5 },
	},
	[7] = {
		Day = 7,
		Name = "Daily Master Title",
		Reward = { Type = RewardType.Title, Id = "DailyMaster" },
	},
}

DailyRewardConfig.List = {
	DailyRewardConfig.Days[1],
	DailyRewardConfig.Days[2],
	DailyRewardConfig.Days[3],
	DailyRewardConfig.Days[4],
	DailyRewardConfig.Days[5],
	DailyRewardConfig.Days[6],
	DailyRewardConfig.Days[7],
}

function DailyRewardConfig.GetDay(Day: number): DailyReward?
	return DailyRewardConfig.Days[Day]
end

function DailyRewardConfig.IsEligible(LastClaimTimestamp: number, Now: number?): boolean
	local CurrentTime = Now or os.time()
	return (CurrentTime - LastClaimTimestamp) >= DailyRewardConfig.CooldownSeconds
end

function DailyRewardConfig.GetTimeUntilNext(LastClaimTimestamp: number, Now: number?): number
	local CurrentTime = Now or os.time()
	local Elapsed = CurrentTime - LastClaimTimestamp
	if Elapsed >= DailyRewardConfig.CooldownSeconds then
		return 0
	end
	return DailyRewardConfig.CooldownSeconds - Elapsed
end

return table.freeze(DailyRewardConfig)
