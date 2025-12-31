import { useState, useMemo } from "react";
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
import { Textarea } from "@/components/ui/textarea";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { expenses, properties, getPropertyById } from "@/data/mockData";
import { formatCurrency, formatDate, getCategoryLabel } from "@/utils/formatters";
import { Plus, Receipt, Wrench, Zap, Shield, Building, Users } from "lucide-react";
import { cn } from "@/lib/utils";

const categoryIcons: Record<string, any> = {
  maintenance: Wrench,
  repairs: Wrench,
  utilities: Zap,
  insurance: Shield,
  property_tax: Building,
  management: Users,
};

const categories = [
  { value: 'maintenance', label: 'Maintenance' },
  { value: 'repairs', label: 'Repairs' },
  { value: 'utilities', label: 'Utilities' },
  { value: 'insurance', label: 'Insurance' },
  { value: 'property_tax', label: 'Property Tax' },
  { value: 'management', label: 'Management Fees' },
];

export function LandlordExpenses() {
  const [isAddOpen, setIsAddOpen] = useState(false);
  const [categoryFilter, setCategoryFilter] = useState<string>("all");

  const filteredExpenses = useMemo(() => {
    let filtered = [...expenses];
    if (categoryFilter !== "all") {
      filtered = filtered.filter(e => e.category === categoryFilter);
    }
    return filtered.sort((a, b) => 
      new Date(b.date).getTime() - new Date(a.date).getTime()
    );
  }, [categoryFilter]);

  const totalExpenses = useMemo(() => {
    return filteredExpenses.reduce((sum, e) => sum + e.amount, 0);
  }, [filteredExpenses]);

  const expensesByCategory = useMemo(() => {
    const byCategory: Record<string, number> = {};
    expenses.forEach(e => {
      byCategory[e.category] = (byCategory[e.category] || 0) + e.amount;
    });
    return byCategory;
  }, []);

  return (
    <div className="space-y-6 animate-fade-in">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Expenses</h1>
          <p className="text-muted-foreground">Track property expenses</p>
        </div>
        <Dialog open={isAddOpen} onOpenChange={setIsAddOpen}>
          <DialogTrigger asChild>
            <Button>
              <Plus className="mr-2 h-4 w-4" />
              Add Expense
            </Button>
          </DialogTrigger>
          <DialogContent>
            <DialogHeader>
              <DialogTitle>Add New Expense</DialogTitle>
            </DialogHeader>
            <form className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="date">Date</Label>
                  <Input id="date" type="date" />
                </div>
                <div className="space-y-2">
                  <Label>Category</Label>
                  <Select>
                    <SelectTrigger>
                      <SelectValue placeholder="Select category" />
                    </SelectTrigger>
                    <SelectContent>
                      {categories.map(c => (
                        <SelectItem key={c.value} value={c.value}>{c.label}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
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
                  <Label htmlFor="vendor">Vendor</Label>
                  <Input id="vendor" placeholder="ABC Services" />
                </div>
              </div>
              <div className="space-y-2">
                <Label htmlFor="amount">Amount</Label>
                <Input id="amount" type="number" placeholder="500" />
              </div>
              <div className="space-y-2">
                <Label htmlFor="description">Description</Label>
                <Textarea id="description" placeholder="Describe the expense..." />
              </div>
              <div className="flex justify-end gap-3 pt-4">
                <Button type="button" variant="outline" onClick={() => setIsAddOpen(false)}>
                  Cancel
                </Button>
                <Button type="submit" onClick={() => setIsAddOpen(false)}>
                  Add Expense
                </Button>
              </div>
            </form>
          </DialogContent>
        </Dialog>
      </div>

      {/* Category Filters */}
      <div className="flex flex-wrap gap-2">
        <Button
          variant={categoryFilter === "all" ? "default" : "outline"}
          size="sm"
          onClick={() => setCategoryFilter("all")}
        >
          All
        </Button>
        {categories.map(c => (
          <Button
            key={c.value}
            variant={categoryFilter === c.value ? "default" : "outline"}
            size="sm"
            onClick={() => setCategoryFilter(c.value)}
          >
            {c.label}
          </Button>
        ))}
      </div>

      {/* Stats */}
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <Card className="shadow-card bg-destructive text-destructive-foreground">
          <CardContent className="pt-6">
            <div className="text-2xl font-bold">{formatCurrency(totalExpenses)}</div>
            <p className="text-sm opacity-90">
              {categoryFilter === "all" ? "Total Expenses" : getCategoryLabel(categoryFilter)}
            </p>
          </CardContent>
        </Card>
        {Object.entries(expensesByCategory).slice(0, 3).map(([cat, amount]) => (
          <Card key={cat} className="shadow-card">
            <CardContent className="pt-6">
              <div className="flex items-center gap-3">
                <div className="rounded-lg bg-muted p-2">
                  {categoryIcons[cat] && 
                    React.createElement(categoryIcons[cat], { className: "h-5 w-5 text-muted-foreground" })
                  }
                </div>
                <div>
                  <div className="text-lg font-bold">{formatCurrency(amount)}</div>
                  <p className="text-sm text-muted-foreground">{getCategoryLabel(cat)}</p>
                </div>
              </div>
            </CardContent>
          </Card>
        ))}
      </div>

      {/* Expenses Table */}
      <Card className="shadow-card">
        <CardHeader>
          <CardTitle className="text-lg">
            {categoryFilter === "all" ? "All Expenses" : getCategoryLabel(categoryFilter)}
          </CardTitle>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Date</TableHead>
                <TableHead>Category</TableHead>
                <TableHead>Property</TableHead>
                <TableHead>Vendor</TableHead>
                <TableHead>Amount</TableHead>
                <TableHead>Description</TableHead>
                <TableHead className="text-right">Receipt</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {filteredExpenses.map((expense) => {
                const property = getPropertyById(expense.propertyId);
                return (
                  <TableRow key={expense.id}>
                    <TableCell className="font-medium">
                      {formatDate(expense.date)}
                    </TableCell>
                    <TableCell>
                      <span className="inline-flex items-center gap-2">
                        {getCategoryLabel(expense.category)}
                      </span>
                    </TableCell>
                    <TableCell>{property?.name}</TableCell>
                    <TableCell>{expense.vendor}</TableCell>
                    <TableCell className="font-medium text-destructive">
                      -{formatCurrency(expense.amount)}
                    </TableCell>
                    <TableCell className="max-w-[200px] truncate text-sm text-muted-foreground">
                      {expense.description}
                    </TableCell>
                    <TableCell className="text-right">
                      <Button variant="ghost" size="sm">
                        <Receipt className="mr-2 h-4 w-4" />
                        View
                      </Button>
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

import React from 'react';
