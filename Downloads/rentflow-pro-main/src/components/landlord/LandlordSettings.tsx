import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Separator } from "@/components/ui/separator";
import { Switch } from "@/components/ui/switch";
import { useAuth } from "@/context/AuthContext";
import { Save, Bell, Mail, Shield, Building2 } from "lucide-react";

export function LandlordSettings() {
  const { user } = useAuth();

  return (
    <div className="space-y-6 animate-fade-in">
      <div>
        <h1 className="text-2xl font-bold text-foreground">Settings</h1>
        <p className="text-muted-foreground">Manage your account and preferences</p>
      </div>

      <div className="grid gap-6 lg:grid-cols-3">
        {/* Profile */}
        <Card className="shadow-card lg:col-span-2">
          <CardHeader>
            <CardTitle className="text-lg flex items-center gap-2">
              <Building2 className="h-5 w-5" />
              Business Profile
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="grid gap-4 sm:grid-cols-2">
              <div className="space-y-2">
                <Label htmlFor="businessName">Business Name</Label>
                <Input id="businessName" defaultValue="Martinez Properties LLC" />
              </div>
              <div className="space-y-2">
                <Label htmlFor="ownerName">Owner Name</Label>
                <Input id="ownerName" defaultValue={user?.name} />
              </div>
            </div>
            <div className="space-y-2">
              <Label htmlFor="email">Email</Label>
              <Input id="email" type="email" defaultValue={user?.email} />
            </div>
            <div className="grid gap-4 sm:grid-cols-2">
              <div className="space-y-2">
                <Label htmlFor="phone">Phone</Label>
                <Input id="phone" defaultValue="(555) 999-8888" />
              </div>
              <div className="space-y-2">
                <Label htmlFor="address">Address</Label>
                <Input id="address" defaultValue="100 Business Ave, Suite 200" />
              </div>
            </div>
            <div className="flex justify-end">
              <Button>
                <Save className="mr-2 h-4 w-4" />
                Save Changes
              </Button>
            </div>
          </CardContent>
        </Card>

        {/* Quick Stats */}
        <Card className="shadow-card">
          <CardHeader>
            <CardTitle className="text-lg">Account Summary</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex justify-between">
              <span className="text-muted-foreground">Properties</span>
              <span className="font-medium">3</span>
            </div>
            <div className="flex justify-between">
              <span className="text-muted-foreground">Active Tenants</span>
              <span className="font-medium">6</span>
            </div>
            <div className="flex justify-between">
              <span className="text-muted-foreground">Total Units</span>
              <span className="font-medium">11</span>
            </div>
            <Separator />
            <div className="flex justify-between">
              <span className="text-muted-foreground">Member Since</span>
              <span className="font-medium">Jan 2024</span>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Notifications */}
      <Card className="shadow-card">
        <CardHeader>
          <CardTitle className="text-lg flex items-center gap-2">
            <Bell className="h-5 w-5" />
            Notifications
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="font-medium">Payment Received</p>
              <p className="text-sm text-muted-foreground">Get notified when a tenant makes a payment</p>
            </div>
            <Switch defaultChecked />
          </div>
          <Separator />
          <div className="flex items-center justify-between">
            <div>
              <p className="font-medium">Invoice Due Reminder</p>
              <p className="text-sm text-muted-foreground">Send reminders to tenants before due date</p>
            </div>
            <Switch defaultChecked />
          </div>
          <Separator />
          <div className="flex items-center justify-between">
            <div>
              <p className="font-medium">Overdue Alerts</p>
              <p className="text-sm text-muted-foreground">Get notified when payments are overdue</p>
            </div>
            <Switch defaultChecked />
          </div>
          <Separator />
          <div className="flex items-center justify-between">
            <div>
              <p className="font-medium">Lease Expiration</p>
              <p className="text-sm text-muted-foreground">Notify 60 days before lease ends</p>
            </div>
            <Switch defaultChecked />
          </div>
        </CardContent>
      </Card>

      {/* Security */}
      <Card className="shadow-card">
        <CardHeader>
          <CardTitle className="text-lg flex items-center gap-2">
            <Shield className="h-5 w-5" />
            Security
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-2">
              <Label htmlFor="currentPassword">Current Password</Label>
              <Input id="currentPassword" type="password" />
            </div>
            <div></div>
            <div className="space-y-2">
              <Label htmlFor="newPassword">New Password</Label>
              <Input id="newPassword" type="password" />
            </div>
            <div className="space-y-2">
              <Label htmlFor="confirmPassword">Confirm Password</Label>
              <Input id="confirmPassword" type="password" />
            </div>
          </div>
          <div className="flex justify-end">
            <Button variant="outline">Update Password</Button>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
