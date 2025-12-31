import { useAuth } from "@/context/AuthContext";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Separator } from "@/components/ui/separator";
import { tenants, getPropertyById } from "@/data/mockData";
import { formatDate } from "@/utils/formatters";
import { User, Mail, Phone, Building2, Calendar, Save } from "lucide-react";

export function TenantProfile() {
  const { user } = useAuth();
  const tenant = tenants.find(t => t.id === user?.id) || tenants[0];
  const property = getPropertyById(tenant.propertyId);

  return (
    <div className="space-y-6 animate-fade-in">
      <div>
        <h1 className="text-2xl font-bold text-foreground">Profile Settings</h1>
        <p className="text-muted-foreground">Manage your account information</p>
      </div>

      <div className="grid gap-6 lg:grid-cols-3">
        {/* Profile Card */}
        <Card className="shadow-card">
          <CardContent className="pt-6">
            <div className="flex flex-col items-center text-center">
              <div className="flex h-20 w-20 items-center justify-center rounded-full bg-primary text-2xl font-bold text-primary-foreground">
                {tenant.name.split(' ').map(n => n[0]).join('')}
              </div>
              <h3 className="mt-4 text-lg font-semibold">{tenant.name}</h3>
              <p className="text-sm text-muted-foreground">{tenant.email}</p>
              <Separator className="my-4" />
              <div className="w-full space-y-3 text-left">
                <div className="flex items-center gap-3 text-sm">
                  <Building2 className="h-4 w-4 text-muted-foreground" />
                  <span>{property?.name}</span>
                </div>
                <div className="flex items-center gap-3 text-sm">
                  <span className="ml-7">{tenant.unitNumber}</span>
                </div>
                <div className="flex items-center gap-3 text-sm">
                  <Calendar className="h-4 w-4 text-muted-foreground" />
                  <span>Lease: {formatDate(tenant.leaseStart)} - {formatDate(tenant.leaseEnd)}</span>
                </div>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Edit Form */}
        <Card className="shadow-card lg:col-span-2">
          <CardHeader>
            <CardTitle className="text-lg">Personal Information</CardTitle>
          </CardHeader>
          <CardContent className="space-y-6">
            <div className="grid gap-4 sm:grid-cols-2">
              <div className="space-y-2">
                <Label htmlFor="firstName">First Name</Label>
                <Input id="firstName" defaultValue={tenant.name.split(' ')[0]} />
              </div>
              <div className="space-y-2">
                <Label htmlFor="lastName">Last Name</Label>
                <Input id="lastName" defaultValue={tenant.name.split(' ')[1]} />
              </div>
            </div>

            <div className="space-y-2">
              <Label htmlFor="email">Email Address</Label>
              <div className="relative">
                <Mail className="absolute left-3 top-3 h-4 w-4 text-muted-foreground" />
                <Input id="email" className="pl-9" defaultValue={tenant.email} />
              </div>
            </div>

            <div className="space-y-2">
              <Label htmlFor="phone">Phone Number</Label>
              <div className="relative">
                <Phone className="absolute left-3 top-3 h-4 w-4 text-muted-foreground" />
                <Input id="phone" className="pl-9" defaultValue={tenant.phone} />
              </div>
            </div>

            <Separator />

            <div>
              <h4 className="mb-4 font-medium">Change Password</h4>
              <div className="grid gap-4 sm:grid-cols-2">
                <div className="space-y-2">
                  <Label htmlFor="currentPassword">Current Password</Label>
                  <Input id="currentPassword" type="password" />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="newPassword">New Password</Label>
                  <Input id="newPassword" type="password" />
                </div>
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
      </div>
    </div>
  );
}
