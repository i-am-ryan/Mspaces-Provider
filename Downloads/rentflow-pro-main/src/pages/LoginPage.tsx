import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { useAuth, UserRole } from "@/context/AuthContext";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Building2, Home, User } from "lucide-react";
import { cn } from "@/lib/utils";
import { toast } from "@/hooks/use-toast";

export function LoginPage() {
  const navigate = useNavigate();
  const { signIn, signUp } = useAuth();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [fullName, setFullName] = useState("");
  const [selectedRole, setSelectedRole] = useState<UserRole>("landlord");
  const [isSignUp, setIsSignUp] = useState(false);
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);

    try {
      if (isSignUp) {
        // Sign up new user
        if (!fullName.trim()) {
          toast({
            variant: "destructive",
            title: "Error",
            description: "Please enter your full name",
          });
          setLoading(false);
          return;
        }

        const { error } = await signUp(email, password, fullName, selectedRole);
        
        if (error) {
          toast({
            variant: "destructive",
            title: "Sign Up Failed",
            description: error.message,
          });
        } else {
          toast({
            title: "Success!",
            description: "Please check your email to verify your account.",
          });
          setIsSignUp(false);
          setFullName("");
          setPassword("");
        }
      } else {
        // Sign in existing user
        const { error } = await signIn(email, password);
        
        if (error) {
          toast({
            variant: "destructive",
            title: "Sign In Failed",
            description: error.message,
          });
        } else {
          toast({
            title: "Welcome back!",
            description: "Redirecting to your dashboard...",
          });
          // Navigation will happen automatically via AuthContext
        }
      }
    } catch (error) {
      toast({
        variant: "destructive",
        title: "Error",
        description: "Something went wrong. Please try again.",
      });
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex min-h-screen items-center justify-center bg-background p-4">
      <div className="w-full max-w-md space-y-8">
        {/* Logo */}
        <div className="flex flex-col items-center text-center">
          <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-primary shadow-lg">
            <Building2 className="h-8 w-8 text-primary-foreground" />
          </div>
          <h1 className="mt-4 text-3xl font-bold text-foreground">RentFlow</h1>
          <p className="mt-2 text-muted-foreground">
            Property management made simple
          </p>
        </div>

        {/* Login/Signup Card */}
        <Card className="shadow-card">
          <CardHeader className="space-y-1 text-center">
            <CardTitle className="text-2xl">
              {isSignUp ? "Create an account" : "Welcome back"}
            </CardTitle>
            <CardDescription>
              {isSignUp 
                ? "Sign up to start managing your properties" 
                : "Sign in to your account to continue"
              }
            </CardDescription>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleSubmit} className="space-y-6">
              {/* Role Selection */}
              <div className="space-y-3">
                <Label>I am a</Label>
                <div className="grid grid-cols-2 gap-3">
                  <button
                    type="button"
                    onClick={() => setSelectedRole("landlord")}
                    className={cn(
                      "flex flex-col items-center gap-2 rounded-lg border-2 p-4 transition-all",
                      selectedRole === "landlord"
                        ? "border-primary bg-primary/5"
                        : "border-border hover:border-primary/50"
                    )}
                  >
                    <div className={cn(
                      "rounded-lg p-2",
                      selectedRole === "landlord" ? "bg-primary" : "bg-muted"
                    )}>
                      <Home className={cn(
                        "h-5 w-5",
                        selectedRole === "landlord" ? "text-primary-foreground" : "text-muted-foreground"
                      )} />
                    </div>
                    <span className={cn(
                      "text-sm font-medium",
                      selectedRole === "landlord" ? "text-primary" : "text-muted-foreground"
                    )}>
                      Landlord
                    </span>
                  </button>
                  <button
                    type="button"
                    onClick={() => setSelectedRole("tenant")}
                    className={cn(
                      "flex flex-col items-center gap-2 rounded-lg border-2 p-4 transition-all",
                      selectedRole === "tenant"
                        ? "border-primary bg-primary/5"
                        : "border-border hover:border-primary/50"
                    )}
                  >
                    <div className={cn(
                      "rounded-lg p-2",
                      selectedRole === "tenant" ? "bg-primary" : "bg-muted"
                    )}>
                      <User className={cn(
                        "h-5 w-5",
                        selectedRole === "tenant" ? "text-primary-foreground" : "text-muted-foreground"
                      )} />
                    </div>
                    <span className={cn(
                      "text-sm font-medium",
                      selectedRole === "tenant" ? "text-primary" : "text-muted-foreground"
                    )}>
                      Tenant
                    </span>
                  </button>
                </div>
              </div>

              {/* Full Name (only for signup) */}
              {isSignUp && (
                <div className="space-y-2">
                  <Label htmlFor="fullName">Full Name</Label>
                  <Input
                    id="fullName"
                    type="text"
                    placeholder="John Smith"
                    value={fullName}
                    onChange={(e) => setFullName(e.target.value)}
                    required
                  />
                </div>
              )}

              {/* Email */}
              <div className="space-y-2">
                <Label htmlFor="email">Email</Label>
                <Input
                  id="email"
                  type="email"
                  placeholder="you@example.com"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  required
                />
              </div>

              {/* Password */}
              <div className="space-y-2">
                <div className="flex items-center justify-between">
                  <Label htmlFor="password">Password</Label>
                  {!isSignUp && (
                    <a href="#" className="text-sm text-primary hover:underline">
                      Forgot password?
                    </a>
                  )}
                </div>
                <Input
                  id="password"
                  type="password"
                  placeholder="••••••••"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  required
                  minLength={6}
                />
                {isSignUp && (
                  <p className="text-xs text-muted-foreground">
                    Must be at least 6 characters
                  </p>
                )}
              </div>

              {/* Submit */}
              <Button type="submit" className="w-full" disabled={loading}>
                {loading 
                  ? "Loading..." 
                  : isSignUp 
                    ? `Sign Up as ${selectedRole === "landlord" ? "Landlord" : "Tenant"}` 
                    : `Sign In as ${selectedRole === "landlord" ? "Landlord" : "Tenant"}`
                }
              </Button>
            </form>

            {/* Toggle Sign Up/Sign In */}
            <div className="mt-6 text-center text-sm">
              <span className="text-muted-foreground">
                {isSignUp ? "Already have an account? " : "Don't have an account? "}
              </span>
              <button
                type="button"
                onClick={() => {
                  setIsSignUp(!isSignUp);
                  setFullName("");
                  setPassword("");
                }}
                className="font-medium text-primary hover:underline"
              >
                {isSignUp ? "Sign in" : "Sign up"}
              </button>
            </div>
          </CardContent>
        </Card>

        {/* Demo Note */}
        <p className="text-center text-xs text-muted-foreground">
          {isSignUp 
            ? "Create your account to get started" 
            : "New user? Sign up above to create an account"
          }
        </p>
      </div>
    </div>
  );
}