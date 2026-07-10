-- ========== Services 状态灯配置 ==========
-- 这个表是 services.lua 和 helpers/services/status.lua 的唯一数据源。
-- 以后增加服务时优先在这里加 group / service，不需要改 UI 逻辑。
return {
	item = {
		name = "services",
	},
	groups = {
		{
			id = "market",
			label = "Market",
			kind = "docker_compose",
			project = "market-data-stack",
			compose_file = "/Users/fuzhuoqun/Database/market-data-stack/docker-compose.yml",
			services = {
				{ id = "metabase", label = "Metabase", port = 3000 },
				{ id = "postgres", label = "Postgres", port = 5432 },
			},
		},
	},
}
