/**
 * Model status - shows the active model and thinking level in the footer.
 * Updates on model changes (Ctrl+P, /model) and thinking level changes.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
	const render = (model: string, thinking: string) => `🤖 ${model} · thinking ${thinking}`;

	pi.on("session_start", async (_event, ctx) => {
		const model = ctx.model ? `${ctx.model.provider}/${ctx.model.id}` : "?";
		ctx.ui.setStatus("model", render(model, ctx.thinkingLevel ?? "?"));
	});

	pi.on("model_select", async (event, ctx) => {
		const next = `${event.model.provider}/${event.model.id}`;
		if (event.source !== "restore") {
			ctx.ui.notify(`Model: ${next}`, "info");
		}
		ctx.ui.setStatus("model", render(next, ctx.thinkingLevel ?? "?"));
	});

	pi.on("thinking_level_select", async (event, ctx) => {
		const model = ctx.model ? `${ctx.model.provider}/${ctx.model.id}` : "?";
		ctx.ui.setStatus("model", render(model, event.level));
	});
}