import { Toaster } from "@/components/ui/toaster";
import { Toaster as Sonner } from "@/components/ui/sonner";
import { TooltipProvider } from "@/components/ui/tooltip";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import { AuthProvider, useAuth } from "@/context/AuthContext";
import { LoginPage } from "@/pages/LoginPage";
import { DashboardLayout } from "@/components/shared/DashboardLayout";
import { TenantDashboard } from "@/components/tenant/TenantDashboard";
import { TenantInvoices } from "@/components/tenant/TenantInvoices";
import { TenantPayments } from "@/components/tenant/TenantPayments";
import { TenantCredits } from "@/components/tenant/TenantCredits";
import { TenantStatement } from "@/components/tenant/TenantStatement";
import { TenantProfile } from "@/components/tenant/TenantProfile";
import { LandlordDashboard } from "@/components/landlord/LandlordDashboard";
import { LandlordProperties } from "@/components/landlord/LandlordProperties";
import { LandlordTenants } from "@/components/landlord/LandlordTenants";
import { LandlordInvoices } from "@/components/landlord/LandlordInvoices";
import { LandlordPayments } from "@/components/landlord/LandlordPayments";
import { LandlordExpenses } from "@/components/landlord/LandlordExpenses";
import { LandlordReports } from "@/components/landlord/LandlordReports";
import { LandlordSettings } from "@/components/landlord/LandlordSettings";
import NotFound from "./pages/NotFound";
import { AuthCallback } from "@/pages/AuthCallback";

const queryClient = new QueryClient();

// Protected Route Component
function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { isAuthenticated, loading, user } = useAuth();

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <div className="text-center">
          <div className="h-8 w-8 animate-spin rounded-full border-4 border-primary border-t-transparent mx-auto mb-4"></div>
          <p className="text-muted-foreground">Loading...</p>
        </div>
      </div>
    );
  }

  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }

  return <>{children}</>;
}

// Root redirect based on authentication
function RootRedirect() {
  const { isAuthenticated, loading, user } = useAuth();

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <div className="text-center">
          <div className="h-8 w-8 animate-spin rounded-full border-4 border-primary border-t-transparent mx-auto mb-4"></div>
          <p className="text-muted-foreground">Loading...</p>
        </div>
      </div>
    );
  }

  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }

  return <Navigate to={user?.role === 'landlord' ? '/landlord' : '/tenant'} replace />;
}

const App = () => (
  <QueryClientProvider client={queryClient}>
    <TooltipProvider>
      <AuthProvider>
        <Toaster />
        <Sonner />
        <BrowserRouter>
          <Routes>
            <Route path="/" element={<RootRedirect />} />
            <Route path="/login" element={<LoginPage />} />
             <Route path="/login" element={<LoginPage />} />
            <Route path="/auth/callback" element={<AuthCallback />} />
            {/* Tenant Routes */}
            <Route path="/tenant" element={
              <ProtectedRoute>
                <DashboardLayout />
              </ProtectedRoute>
            }>
              <Route index element={<TenantDashboard />} />
              <Route path="invoices" element={<TenantInvoices />} />
              <Route path="payments" element={<TenantPayments />} />
              <Route path="credits" element={<TenantCredits />} />
              <Route path="statement" element={<TenantStatement />} />
              <Route path="profile" element={<TenantProfile />} />
            </Route>



            {/* Landlord Routes */}
            <Route path="/landlord" element={
              <ProtectedRoute>
                <DashboardLayout />
              </ProtectedRoute>
            }>
              <Route index element={<LandlordDashboard />} />
              <Route path="properties" element={<LandlordProperties />} />
              <Route path="tenants" element={<LandlordTenants />} />
              <Route path="invoices" element={<LandlordInvoices />} />
              <Route path="payments" element={<LandlordPayments />} />
              <Route path="expenses" element={<LandlordExpenses />} />
              <Route path="reports" element={<LandlordReports />} />
              <Route path="settings" element={<LandlordSettings />} />
            </Route>
            

            <Route path="*" element={<NotFound />} />
          </Routes>
        </BrowserRouter>
      </AuthProvider>
    </TooltipProvider>
  </QueryClientProvider>
);

export default App;