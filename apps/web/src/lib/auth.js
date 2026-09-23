import { signOutSession } from './sessionNetwork';

export function logout(navigate) {
  void signOutSession();
  navigate('/');
}
