const v = require('../lib/validate');
const versionedLogs = require('../lib/versionedLogs');

function readSleep(body) {
  return {
    hours: v.num(body.hours, 'hours', { min: 0, max: 24 }),
    quality: v.str(body.quality, 'quality', { required: false, max: 32 }),
    bedtime: v.str(body.bedtime, 'bedtime', { required: false, max: 16 }),
    wake_time: v.str(body.wakeTime ?? body.wake_time, 'wakeTime', { required: false, max: 16 }),
  };
}

module.exports = versionedLogs({
  collection: 'sleep',
  kind: 'sleep',
  label: 'Sleep entry',
  read: readSleep,
});
