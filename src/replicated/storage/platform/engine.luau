--!strict
const RunService = game:GetService("RunService")

const is_server = RunService:IsServer()

return table.freeze {
    is_server = is_server,
    is_studio = RunService:IsStudio(),
    is_private = is_server and game.PrivateServerId ~= "",
    is_reserved = is_server and game.PrivateServerOwnerId == 0 and game.PrivateServerId ~= "",
    job_id = game.JobId,

	render = RunService.PreRender,
	frame = RunService.Heartbeat,
	prephysic = RunService.PreSimulation,
	postphysic = RunService.PostSimulation,
	preanim = RunService.PreAnimation
}