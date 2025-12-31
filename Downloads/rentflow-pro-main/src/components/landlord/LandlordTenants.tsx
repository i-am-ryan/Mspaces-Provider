import { useState, useMemo } from "react";
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
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { tenants, properties, getPropertyById } from "@/data/mockData";
import { formatCurrency, formatDate } from "@/utils/formatters";
import { Plus, User, FileText, DollarSign, Users } from "lucide-react";

export function LandlordTenants() {
  const [isAddOpen, setIsAddOpen] = useState(false);

  const stats = useMemo(() => ({
    total: tenants.length,
    current: tenants.filter(t => t.status === 'current').length,
    expiring: tenants.filter(t => t.status === 'expiring').length,
    overdue: tenants.filter(t => t.status === 'overdue').length,
  }), []);

  return (
    <div className="space-y-6 animate-fade-in">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Tenants</h1>
          <p className="text-muted-foreground">Manage your tenants</p>
        </div>
        <Dialog open={isAddOpen} onOpenChange={setIsAddOpen}>
          <DialogTrigger asChild>
            <Button>
              <Plus className="mr-2 h-4 w-4" />
              Add Tenant
            </Button>
          </DialogTrigger>
          <DialogContent className="sm:max-w-[500px]">
            <DialogHeader>
              <DialogTitle>Add New Tenant</DialogTitle>
            </DialogHeader>
            <form className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="name">Full Name</Label>
                  <Input id="name" placeholder="John Smith" />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="phone">Phone</Label>
                  <Input id="phone" placeholder="(555) 123-4567" />
                </div>
              </div>
              <div className="space-y-2">
                <Label htmlFor="email">Email</Label>
                <Input id="email" type="email" placeholder="john@email.com" />
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label>Property</Label>
                  <Select>
                    <SelectTrigger>
                      <SelectValue placeholder="Select property" />
                    </SelectTrigger>
                    <SelectContent>
                      {properties.map(p => (
                        <SelectItem key={p.id} value={p.id}>{p.name}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div className="space-y-2">
                  <Label htmlFor="unit">Unit Number</Label>
                  <Input id="unit" placeholder="Unit 101" />
                </div>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="leaseStart">Lease Start</Label>
                  <Input id="leaseStart" type="date" />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="leaseEnd">Lease End</Label>
                  <Input id="leaseEnd" type="date" />
                </div>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="rent">Monthly Rent</Label>
                  <Input id="rent" type="number" placeholder="1500" />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="deposit">Security Deposit</Label>
                  <Input id="deposit" type="number" placeholder="3000" />
                </div>
              </div>
              <div className="flex justify-end gap-3 pt-4">
                <Button type="button" variant="outline" onClick={() => setIsAddOpen(false)}>
                  Cancel
                </Button>
                <Button type="submit" onClick={() => setIsAddOpen(false)}>
                  Add Tenant
                </Button>
              </div>
            </form>
          </DialogContent>
        </Dialog>
      </div>

      {/* Stats */}
      <div className="grid gap-4 sm:grid-cols-4">
        <Card className="shadow-card">
          <CardContent className="pt-6">
            <div className="flex items-center gap-3">
              <div className="rounded-lg bg-primary/10 p-3">
                <Users className="h-5 w-5 text-primary" />
              </div>
              <div>
                <div className="text-2xl font-bold">{stats.total}</div>
                <p className="text-sm text-muted-foreground">Total Tenants</p>
              </div>
            </div>
          </CardContent>
        </Card>
        <Card className="shadow-card">
          <CardContent className="pt-6">
            <div className="text-2xl font-bold text-success">{stats.current}</div>
            <p className="text-sm text-muted-foreground">Current</p>
          </CardContent>
        </Card>
        <Card className="shadow-card">
          <CardContent className="pt-6">
            <div className="text-2xl font-bold text-warning">{stats.expiring}</div>
            <p className="text-sm text-muted-foreground">Lease Expiring</p>
          </CardContent>
        </Card>
        <Card className="shadow-card">
          <CardContent className="pt-6">
            <div className="text-2xl font-bold text-destructive">{stats.overdue}</div>
            <p className="text-sm text-muted-foreground">Payment Overdue</p>
          </CardContent>
        </Card>
      </div>

      {/* Tenants Table */}
      <Card className="shadow-card">
        <CardHeader>
          <CardTitle className="text-lg">All Tenants</CardTitle>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Tenant</TableHead>
                <TableHead>Property</TableHead>
                <TableHead>Lease Period</TableHead>
                <TableHead>Monthly Rent</TableHead>
                <TableHead>Status</TableHead>
                <TableHead className="text-right">Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {tenants.map((tenant) => {
                const property = getPropertyById(tenant.propertyId);
                return (
                  <TableRow key={tenant.id}>
                    <TableCell>
                      <div className="flex items-center gap-3">
                        <div className="flex h-9 w-9 items-center justify-center rounded-full bg-primary/10 text-sm font-medium text-primary">
                          {tenant.name.split(' ').map(n => n[0]).join('')}
                        </div>
                        <div>
                          <p className="font-medium">{tenant.name}</p>
                          <p className="text-sm text-muted-foreground">{tenant.email}</p>
                        </div>
                      </div>
                    </TableCell>
                    <TableCell>
                      <div>
                        <p className="font-medium">{property?.name}</p>
                        <p className="text-sm text-muted-foreground">{tenant.unitNumber}</p>
                      </div>
                    </TableCell>
                    <TableCell>
                      <p className="text-sm">
                        {formatDate(tenant.leaseStart)} - {formatDate(tenant.leaseEnd)}
                      </p>
                    </TableCell>
                    <TableCell className="font-medium">
                      {formatCurrency(tenant.monthlyRent)}
                    </TableCell>
                    <TableCell>
                      <StatusBadge variant={tenant.status}>
                        {tenant.status === 'current' ? 'Current' : 
                         tenant.status === 'expiring' ? 'Expiring Soon' : 'Overdue'}
                      </StatusBadge>
                    </TableCell>
                    <TableCell className="text-right">
                      <div className="flex justify-end gap-2">
                        <Button variant="ghost" size="sm">
                          <User className="mr-2 h-4 w-4" />
                          View
                        </Button>
                        <Button variant="ghost" size="sm">
                          <FileText className="mr-2 h-4 w-4" />
                          Invoice
                        </Button>
                        <Button variant="ghost" size="sm">
                          <DollarSign className="mr-2 h-4 w-4" />
                          Payment
                        </Button>
                      </div>
                    </TableCell>
                  </TableRow>
                );
              })}
            </TableBody>
          </Table>
        </CardContent>
      </Card>
    </div>
  );
}
