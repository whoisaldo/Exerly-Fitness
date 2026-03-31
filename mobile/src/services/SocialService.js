import apiClient from '../api/client';

/**
 * Search users by email.
 * @param {string} email
 * @returns {Promise<Array>}
 */
export async function searchUser(email) {
  const res = await apiClient.get('/api/social/search', { params: { email } });
  return res.data;
}

/**
 * Add a friend by email.
 * @param {string} email
 * @returns {Promise<object>}
 */
export async function addFriend(email) {
  const res = await apiClient.post('/api/social/friends', { email });
  return res.data;
}

/**
 * Get friend list.
 * @returns {Promise<Array>}
 */
export async function getFriends() {
  const res = await apiClient.get('/api/social/friends');
  return res.data;
}

/**
 * Get a friend's recent activity.
 * @param {string} friendId
 * @returns {Promise<Array>}
 */
export async function getFriendActivity(friendId) {
  const res = await apiClient.get(`/api/social/friends/${friendId}/activity`);
  return res.data;
}

/**
 * Create a new challenge.
 * @param {{ name: string, type: string, duration: number, friendIds: string[] }} data
 * @returns {Promise<object>}
 */
export async function createChallenge(data) {
  const res = await apiClient.post('/api/challenges', data);
  return res.data;
}

/**
 * Get all challenges.
 * @returns {Promise<Array>}
 */
export async function getChallenges() {
  const res = await apiClient.get('/api/challenges');
  return res.data;
}

/**
 * Get challenge detail.
 * @param {string} id
 * @returns {Promise<object>}
 */
export async function getChallengeDetail(id) {
  const res = await apiClient.get(`/api/challenges/${id}`);
  return res.data;
}
