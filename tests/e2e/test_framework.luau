--!strict
-- test_framework.luau
-- Lightweight E2E assertion and reporting framework for Roblox Studio context.

export type TestCase = {
	Name: string,
	Tier: string,
	Feature: string?,
	Fn: () -> (),
}

export type TestResult = {
	Name: string,
	Tier: string,
	Feature: string?,
	Passed: boolean,
	DurationMs: number,
	Error: string?,
}

export type SuiteReport = {
	Total: number,
	Passed: number,
	Failed: number,
	DurationMs: number,
	Results: { TestResult },
	TierSummary: { [string]: { Total: number, Passed: number, Failed: number } },
}

local Framework = {}
local Tests: { TestCase } = {}

function Framework.Assert(Condition: boolean, Message: string?)
	if not Condition then
		error(Message or "Assertion failed", 2)
	end
end

function Framework.AssertEqual<T>(Actual: T, Expected: T, Message: string?)
	if Actual ~= Expected then
		local msg = string.format(
			"%s (Expected: %s [%s], Actual: %s [%s])",
			Message or "AssertEqual failed",
			tostring(Expected),
			typeof(Expected),
			tostring(Actual),
			typeof(Actual)
		)
		error(msg, 2)
	end
end

function Framework.AssertNotEqual<T>(Actual: T, Expected: T, Message: string?)
	if Actual == Expected then
		local msg =
			string.format("%s (Expected value not to be: %s)", Message or "AssertNotEqual failed", tostring(Expected))
		error(msg, 2)
	end
end

function Framework.AssertTrue(Condition: boolean, Message: string?)
	if Condition ~= true then
		error(Message or ("Expected true, got " .. tostring(Condition)), 2)
	end
end

function Framework.AssertFalse(Condition: boolean, Message: string?)
	if Condition ~= false then
		error(Message or ("Expected false, got " .. tostring(Condition)), 2)
	end
end

function Framework.AssertNil(Value: any, Message: string?)
	if Value ~= nil then
		error(Message or ("Expected nil, got " .. tostring(Value)), 2)
	end
end

function Framework.AssertNotNil(Value: any, Message: string?)
	if Value == nil then
		error(Message or "Expected non-nil value", 2)
	end
end

function Framework.AssertApprox(Actual: number, Expected: number, Epsilon: number?, Message: string?)
	local eps = Epsilon or 0.001
	if math.abs(Actual - Expected) > eps then
		local msg = string.format(
			"%s (Expected approx: %f, Actual: %f, Diff: %f, Epsilon: %f)",
			Message or "AssertApprox failed",
			Expected,
			Actual,
			math.abs(Actual - Expected),
			eps
		)
		error(msg, 2)
	end
end

function Framework.AssertMatch(Actual: string, Pattern: string, Message: string?)
	if not string.match(Actual, Pattern) then
		local msg = string.format(
			"%s (String '%s' did not match pattern '%s')",
			Message or "AssertMatch failed",
			Actual,
			Pattern
		)
		error(msg, 2)
	end
end

function Framework.RegisterTest(Tier: string, Name: string, Fn: () -> (), Feature: string?)
	table.insert(Tests, {
		Tier = Tier,
		Name = Name,
		Feature = Feature,
		Fn = Fn,
	})
end

function Framework.ClearTests()
	table.clear(Tests)
end

function Framework.RunAll(): SuiteReport
	local Results: { TestResult } = {}
	local PassedCount = 0
	local FailedCount = 0
	local StartTime = os.clock()
	local TierSummary: { [string]: { Total: number, Passed: number, Failed: number } } = {}

	for _, test in ipairs(Tests) do
		if not TierSummary[test.Tier] then
			TierSummary[test.Tier] = { Total = 0, Passed = 0, Failed = 0 }
		end
		TierSummary[test.Tier].Total += 1

		local testStart = os.clock()
		local success, err = pcall(test.Fn)
		local durationMs = math.floor((os.clock() - testStart) * 1000 + 0.5)

		if success then
			PassedCount += 1
			TierSummary[test.Tier].Passed += 1
			table.insert(Results, {
				Name = test.Name,
				Tier = test.Tier,
				Feature = test.Feature,
				Passed = true,
				DurationMs = durationMs,
				Error = nil,
			})
		else
			FailedCount += 1
			TierSummary[test.Tier].Failed += 1
			table.insert(Results, {
				Name = test.Name,
				Tier = test.Tier,
				Feature = test.Feature,
				Passed = false,
				DurationMs = durationMs,
				Error = tostring(err),
			})
		end
	end

	local TotalDurationMs = math.floor((os.clock() - StartTime) * 1000 + 0.5)

	return {
		Total = #Tests,
		Passed = PassedCount,
		Failed = FailedCount,
		DurationMs = TotalDurationMs,
		Results = Results,
		TierSummary = TierSummary,
	}
end

return Framework
