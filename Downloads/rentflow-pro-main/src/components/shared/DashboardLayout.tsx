import { useState } from "react";
import { Outlet, Navigate } from "react-router-dom";
import { useAuth } from "@/context/AuthContext";
import { Navbar } from "./Navbar";
import { Sidebar } from "./Sidebar";

export function DashboardLayout() {
  const { isAuthenticated, user } = useAuth();
  const [sidebarOpen, setSidebarOpen] = useState(false);

  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }

  return (
    <div className="min-h-screen bg-background">
      <Navbar onMenuClick={() => setSidebarOpen(true)} />
      <Sidebar isOpen={sidebarOpen} onClose={() => setSidebarOpen(false)} />
      <main className="lg:pl-64">
        <div className="container mx-auto p-4 lg:p-6">
          <Outlet />
        </div>
      </main>
    </div>
  );
}
