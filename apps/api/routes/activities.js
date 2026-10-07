const v = require('../lib/validate');
const versionedLogs = require('../lib/versionedLogs');

function readActivity(body) {
  return {
    activity: v.str(body.activity, 'activity', { max: 120 }),
    duration_min: v.num(body.duration_min ?? body.durationMin, 'duration', {
      min: 0.1,
      max: 1440,
    }),
    calories: v.num(body.calories, 'calories', { required: false, min: 0, max: 20000 }),
    intensity: v.str(body.intensity, 'intensity', { required: false, max: 32 }),
    type: v.str(body.type, 'type', { required: false, max: 48 }),
  };
}

module.exports = versionedLogs({
  collection: 'activities',
  kind: 'activity',
  label: 'Activity',
  read: readActivity,
});
