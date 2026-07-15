--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EvaeraPromise = require(ReplicatedStorage.Packages.Promise)

export type Status = "Started" | "Resolved" | "Rejected" | "Cancelled"

export type PromiseChain = {
	andThen: (
		self: PromiseChain,
		successHandler: ((value: any) -> any)?,
		failureHandler: ((reason: any) -> any)?
	) -> PromiseChain,
	catch: (self: PromiseChain, failureHandler: (reason: any) -> any) -> PromiseChain,
	tap: (self: PromiseChain, tapHandler: (value: any) -> any) -> PromiseChain,
	finally: (self: PromiseChain, finallyHandler: ((status: Status) -> any)?) -> PromiseChain,
	timeout: (self: PromiseChain, seconds: number, rejectionValue: any?) -> PromiseChain,
	now: (self: PromiseChain, rejectionValue: any?) -> PromiseChain,
	getStatus: (self: PromiseChain) -> Status,
	awaitStatus: (self: PromiseChain) -> (Status, any),
	await: (self: PromiseChain) -> (boolean, any),
	expect: (self: PromiseChain) -> any,
	cancel: (self: PromiseChain) -> (),
}

export type Promise<T> = {
	andThen: (
		self: Promise<T>,
		successHandler: ((value: T) -> any)?,
		failureHandler: ((reason: any) -> any)?
	) -> PromiseChain,
	catch: (self: Promise<T>, failureHandler: (reason: any) -> any) -> PromiseChain,
	tap: (self: Promise<T>, tapHandler: (value: T) -> any) -> Promise<T>,
	finally: (self: Promise<T>, finallyHandler: ((status: Status) -> any)?) -> Promise<T>,
	timeout: (self: Promise<T>, seconds: number, rejectionValue: any?) -> Promise<T>,
	now: (self: Promise<T>, rejectionValue: any?) -> Promise<T>,
	getStatus: (self: Promise<T>) -> Status,
	awaitStatus: (self: Promise<T>) -> (Status, T),
	await: (self: Promise<T>) -> (boolean, T),
	expect: (self: Promise<T>) -> T,
	cancel: (self: Promise<T>) -> (),
}

export type Executor<T> = (
	resolve: (value: T) -> (),
	reject: (reason: any) -> (),
	onCancel: (cancellationHook: (() -> ())?) -> boolean
) -> ()

type PromiseLibrary = {
	new: <T>(executor: Executor<T>) -> Promise<T>,
	defer: <T>(executor: Executor<T>) -> Promise<T>,
	resolve: <T>(value: T) -> Promise<T>,
	reject: <T>(reason: any) -> Promise<T>,
	delay: (seconds: number) -> Promise<number>,
	is: (value: any) -> boolean,
	Status: {
		Started: Status,
		Resolved: Status,
		Rejected: Status,
		Cancelled: Status,
	},
}

-- Evaera Promise 4 is a dynamically typed Lua module. Keep that runtime, but
-- expose the subset of its stable public API used by CompyAgent as Luau types.
return (EvaeraPromise :: any) :: PromiseLibrary
