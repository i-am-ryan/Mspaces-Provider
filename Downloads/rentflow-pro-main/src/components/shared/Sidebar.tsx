import { NavLink, useLocation } from "react-router-dom";
import { cn } from "@/lib/utils";
import { useAuth } from "@/context/AuthContext";
import {
  LayoutDashboard,
  FileText,
  CreditCard,
  Receipt,
  ClipboardList,
  User,
  Building2,
  Users,
  DollarSign,
  PiggyBank,
  BarChart3,
  Settings,
  X,
} from "lucide-react";
import { Button } from "@/components/ui/button";

interface SidebarProps {
  isOpen: boolean;
  onClose: () => void;
}

const landlordMenuItems = [
  { name: "Dashboard", path: "/landlord", icon: LayoutDashboard },
  { name: "Properties", path: "/landlord/properties", icon: Building2 },
  { name: "Tenants", path: "/landlord/tenants", icon: Users },
  { name: "Invoices", path: "/landlord/invoices", icon: FileText },
  { name: "Payments", path: "/landlord/payments", icon: DollarSign },
  { name: "Expenses", path: "/landlord/expenses", icon: PiggyBank },
  { name: "Reports", path: "/landlord/reports", icon: BarChart3 },
  { name: "Settings", path: "/landlord/settings", icon: Settings },
];

const tenantMenuItems = [
  { name: "Dashboard", path: "/tenant", icon: LayoutDashboard },
  { name: "My Invoices", path: "/tenant/invoices", icon: FileText },
  { name: "Payment History", path: "/tenant/payments", icon: CreditCard },
  { name: "Credit Notes", path: "/tenant/credits", icon: Receipt },
  { name: "Account Statement", path: "/tenant/statement", icon: ClipboardList },
  { name: "Profile Settings", path: "/tenant/profile", icon: User },
];

export function Sidebar({ isOpen, onClose }: SidebarProps) {
  const { user } = useAuth();
  const location = useLocation();
  
  const menuItems = user?.role === "landlord" ? landlordMenuItems : tenantMenuItems;

  return (
    <>
      {/* Mobile overlay */}
      {isOpen && (
        <div
          className="fixed inset-0 z-40 bg-black/50 lg:hidden"
          onClick={onClose}
        />
      )}

      {/* Sidebar */}
      <aside
        className={cn(
          "fixed left-0 top-16 z-40 h-[calc(100vh-4rem)] w-64 transform border-r border-sidebar-border bg-sidebar transition-transform duration-300 ease-in-out lg:translate-x-0",
          isOpen ? "translate-x-0" : "-translate-x-full"
        )}
      >
        <div className="flex h-full flex-col">
          {/* Mobile close button */}
          <div className="flex items-center justify-between p-4 lg:hidden">
            <span className="text-sm font-medium text-sidebar-foreground">
              Menu
            </span>
            <Button
              variant="ghost"
              size="icon"
              onClick={onClose}
              className="text-sidebar-foreground hover:bg-sidebar-accent"
            >
              <X className="h-5 w-5" />
            </Button>
          </div>

          {/* Navigation */}
          <nav className="flex-1 space-y-1 p-4">
            {menuItems.map((item) => {
              const isActive = location.pathname === item.path;
              return (
                <NavLink
                  key={item.path}
                  to={item.path}
                  onClick={onClose}
                  className={cn(
                    "flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors",
                    isActive
                      ? "bg-sidebar-primary text-sidebar-primary-foreground"
                      : "text-sidebar-foreground hover:bg-sidebar-accent hover:text-sidebar-accent-foreground"
                  )}
                >
                  <item.icon className="h-5 w-5" />
                  {item.name}
                </NavLink>
              );
            })}
          </nav>

          {/* Footer */}
          <div className="border-t border-sidebar-border p-4">
            <div className="rounded-lg bg-sidebar-accent p-3">
              <p className="text-xs text-sidebar-muted">
                {user?.role === "landlord" 
                  ? "Managing 3 properties" 
                  : "Tenant at Sunset Apartments"}
              </p>
            </div>
          </div>
        </div>
      </aside>
    </>
  );
}
