import { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '@/lib/supabase';

export function AuthCallback() {
  const navigate = useNavigate();

  useEffect(() => {
    const handleCallback = async () => {
      try {
        // Supabase redirects with tokens in URL hash after email verification
        const hashParams = new URLSearchParams(window.location.hash.substring(1));
        const accessToken = hashParams.get('access_token');
        const refreshToken = hashParams.get('refresh_token');

        if (accessToken && refreshToken) {
          // Set the session with the tokens
          const { error: sessionError } = await supabase.auth.setSession({
            access_token: accessToken,
            refresh_token: refreshToken,
          });

          if (sessionError) {
            console.error('Session error:', sessionError);
            navigate('/login?error=session_failed', { replace: true });
            return;
          }

          // Get current user
          const { data: { user }, error: userError } = await supabase.auth.getUser();

          if (userError || !user) {
            console.error('User error:', userError);
            navigate('/login?error=user_not_found', { replace: true });
            return;
          }

          // Get user role from profile
          const { data: profile, error: profileError } = await supabase
            .from('profiles')
            .select('role')
            .eq('id', user.id)
            .single();

          if (profileError) {
            console.error('Profile error:', profileError);
            navigate('/login?error=profile_not_found', { replace: true });
            return;
          }

          // Redirect based on role
          const redirectPath = profile.role === 'landlord' ? '/landlord' : '/tenant';
          navigate(redirectPath, { replace: true });
          return;
        }

        // No tokens found, redirect to login
        navigate('/login', { replace: true });
      } catch (error) {
        console.error('Auth callback error:', error);
        navigate('/login?error=callback_failed', { replace: true });
      }
    };

    handleCallback();
  }, [navigate]);

  return (
    <div className="flex min-h-screen items-center justify-center">
      <div className="text-center">
        <div className="h-8 w-8 animate-spin rounded-full border-4 border-primary border-t-transparent mx-auto mb-4"></div>
        <p className="text-muted-foreground">Signing you in...</p>
      </div>
    </div>
  );
}