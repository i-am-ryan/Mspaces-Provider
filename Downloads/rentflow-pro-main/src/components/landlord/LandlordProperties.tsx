import { useState } from "react";
import { StatusBadge } from "@/components/ui/status-badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { properties, tenants } from "@/data/mockData";
import { formatCurrency } from "@/utils/formatters";
import { Building2, Plus, Users, DollarSign, Eye, UserPlus } from "lucide-react";

export function LandlordProperties() {
  const [isAddOpen, setIsAddOpen] = useState(false);

  const getPropertyTenants = (propertyId: string) => {
    return tenants.filter(t => t.propertyId === propertyId);
  };

  const getPropertyIncome = (propertyId: string) => {
    const propertyTenants = getPropertyTenants(propertyId);
    return propertyTenants.reduce((sum, t) => sum + t.monthlyRent, 0);
  };

  return (
    <div className="space-y-6 animate-fade-in">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Properties</h1>
          <p className="text-muted-foreground">Manage your rental properties</p>
        </div>
        <Dialog open={isAddOpen} onOpenChange={setIsAddOpen}>
          <DialogTrigger asChild>
            <Button>
              <Plus className="mr-2 h-4 w-4" />
              Add Property
            </Button>
          </DialogTrigger>
          <DialogContent className="sm:max-w-[500px]">
            <DialogHeader>
              <DialogTitle>Add New Property</DialogTitle>
            </DialogHeader>
            <form className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="name">Property Name</Label>
                <Input id="name" placeholder="e.g., Sunset Apartments" />
              </div>
              <div className="space-y-2">
                <Label htmlFor="address">Address</Label>
                <Input id="address" placeholder="123 Main St, City, State ZIP" />
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="units">Number of Units</Label>
                  <Input id="units" type="number" placeholder="1" />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="rent">Monthly Rent per Unit</Label>
                  <Input id="rent" type="number" placeholder="1500" />
                </div>
              </div>
              <div className="space-y-2">
                <Label htmlFor="type">Property Type</Label>
                <Select>
                  <SelectTrigger>
                    <SelectValue placeholder="Select type" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="apartment">Apartment</SelectItem>
                    <SelectItem value="house">House</SelectItem>
                    <SelectItem value="condo">Condo</SelectItem>
                    <SelectItem value="commercial">Commercial</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div className="flex justify-end gap-3 pt-4">
                <Button type="button" variant="outline" onClick={() => setIsAddOpen(false)}>
                  Cancel
                </Button>
                <Button type="submit" onClick={() => setIsAddOpen(false)}>
                  Add Property
                </Button>
              </div>
            </form>
          </DialogContent>
        </Dialog>
      </div>

      {/* Property Cards Grid */}
      <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
        {properties.map((property) => {
          const propertyTenants = getPropertyTenants(property.id);
          const monthlyIncome = getPropertyIncome(property.id);

          return (
            <Card key={property.id} className="shadow-card overflow-hidden hover:shadow-card-hover transition-shadow">
              {/* Property Image */}
              <div className="relative h-48">
                <img
                  src={property.image}
                  alt={property.name}
                  className="h-full w-full object-cover"
                />
                <div className="absolute top-3 right-3">
                  <StatusBadge variant={property.status}>
                    {property.status.charAt(0).toUpperCase() + property.status.slice(1)}
                  </StatusBadge>
                </div>
              </div>

              <CardContent className="p-4">
                <h3 className="font-semibold text-lg">{property.name}</h3>
                <p className="text-sm text-muted-foreground mt-1">{property.address}</p>

                <div className="grid grid-cols-2 gap-4 mt-4">
                  <div className="flex items-center gap-2">
                    <div className="rounded-lg bg-primary/10 p-2">
                      <Users className="h-4 w-4 text-primary" />
                    </div>
                    <div>
                      <p className="text-sm font-medium">{property.occupiedUnits}/{property.units}</p>
                      <p className="text-xs text-muted-foreground">Units</p>
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    <div className="rounded-lg bg-success/10 p-2">
                      <DollarSign className="h-4 w-4 text-success" />
                    </div>
                    <div>
                      <p className="text-sm font-medium">{formatCurrency(monthlyIncome)}</p>
                      <p className="text-xs text-muted-foreground">Monthly</p>
                    </div>
                  </div>
                </div>

                <div className="flex gap-2 mt-4">
                  <Button variant="outline" size="sm" className="flex-1">
                    <Eye className="mr-2 h-4 w-4" />
                    View
                  </Button>
                  <Button variant="outline" size="sm" className="flex-1">
                    <UserPlus className="mr-2 h-4 w-4" />
                    Add Tenant
                  </Button>
                </div>
              </CardContent>
            </Card>
          );
        })}
      </div>
    </div>
  );
}
