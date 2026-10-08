extends RefCounted
## Godot 4.7.2's Web template pads GL tables up to a shared monotonic ID.
## Immediate vector drawing retires buffers/VAOs/fences each frame; empty
## slots otherwise retain ever-larger JavaScript arrays despite GPU deletion.
## Recycle only handles that the original delete path has released. Keep
## every live handle unique across all tables and retain the stock allocator
## as the fallback. No GPU object, waveform or export template is replaced.

const SCRIPT = """
(function () {
  if (typeof GL !== 'object' || typeof GLctx !== 'object' ||
      typeof GL.getNewId !== 'function' || !Array.isArray(GL.buffers) ||
      !Array.isArray(GL.vaos) || !Array.isArray(GL.syncs)) return false;
  if (window.moonPendulumGLHandles) return true;
  const tables = ['buffers', 'vaos', 'syncs', 'textures', 'shaders',
    'programs', 'framebuffers', 'renderbuffers', 'queries', 'samplers',
    'contexts', 'uniforms', 'transformFeedbacks'].map(name => GL[name]).filter(Array.isArray);
  const free = [], queued = new Set(), original = GL.getNewId;
  const stats = {installed:true, reused:0, free:0, highest:GL.counter-1};
  const deletes = [['deleteBuffer','buffers'],
    ['deleteVertexArray','vaos'], ['deleteSync','syncs']];
  if (deletes.some(([method]) => typeof GLctx[method] !== 'function')) return false;
  for (const [method, tableName] of deletes) {
    const remove = GLctx[method];
    GLctx[method] = function (object) {
      const id = object && object.name;
      const owned = Number.isInteger(id) && id > 0 && GL[tableName][id] === object;
      const result = remove.call(this, object);
      if (owned && !queued.has(id)) {
        queued.add(id); free.push(id); stats.free = free.length;
      }
      return result;
    };
  }
  GL.getNewId = function (table) {
    while (free.length) {
      const id = free.pop(); queued.delete(id); stats.free = free.length;
      // The stock wrapper clears its table after delete returns. Reuse only
      // after that has happened, and never alias another live object type.
      if (tables.every(objects => !objects[id])) {
        stats.reused++; return id;
      }
    }
    const id = original.call(this, table);
    stats.highest = Math.max(stats.highest, id);
    return id;
  };
  window.moonPendulumGLHandles = stats;
  return true;
})()
"""

static func install() -> bool:
	if not OS.has_feature("web") or Engine.get_version_info()["hex"] != 0x040702:
		return false
	return bool(JavaScriptBridge.eval(SCRIPT))
