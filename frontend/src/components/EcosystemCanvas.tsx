"use client";

import { useEffect, useRef, useCallback } from "react";
import { useEcosystemStore } from "@/stores/ecosystem";
import { Creature, POOL_TYPE_COLORS } from "@/lib/types";

interface Node {
  creature: Creature;
  x: number;
  y: number;
  vx: number;
  vy: number;
  radius: number;
  color: string;
  alpha: number;
  pulsePhase: number;
}

export default function EcosystemCanvas() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const nodesRef = useRef<Node[]>([]);
  const animRef = useRef<number>(0);
  const hoveredRef = useRef<Node | null>(null);

  const creatures = useEcosystemStore((s) => s.creatures);
  const openInspector = useEcosystemStore((s) => s.openInspector);

  // ── Build nodes from creatures ─────────────────────────────
  useEffect(() => {
    const alive = creatures.filter((c) => c.isAlive);
    const totalBalance = alive.reduce((s, c) => s + c.balance, 0) || 1;
    const canvas = canvasRef.current;
    if (!canvas) return;
    const W = canvas.offsetWidth;
    const H = canvas.offsetHeight;

    nodesRef.current = alive.map((creature, i) => {
      const frac = creature.balance / totalBalance;
      const radius = Math.max(12, Math.sqrt(frac) * 120);
      const angle = (i / alive.length) * Math.PI * 2;
      const spread = Math.min(W, H) * 0.3;
      return {
        creature,
        x: W / 2 + Math.cos(angle) * spread + (Math.random() - 0.5) * 40,
        y: H / 2 + Math.sin(angle) * spread + (Math.random() - 0.5) * 40,
        vx: (Math.random() - 0.5) * 0.3,
        vy: (Math.random() - 0.5) * 0.3,
        radius,
        color: POOL_TYPE_COLORS[creature.dna.poolType] || "#6EE7B7",
        alpha: 1,
        pulsePhase: Math.random() * Math.PI * 2,
      };
    });
  }, [creatures]);

  // ── Animation loop ─────────────────────────────────────────
  const draw = useCallback(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    const dpr = window.devicePixelRatio || 1;
    const W = canvas.offsetWidth;
    const H = canvas.offsetHeight;
    canvas.width = W * dpr;
    canvas.height = H * dpr;
    ctx.scale(dpr, dpr);

    const nodes = nodesRef.current;
    const time = Date.now() / 1000;

    // Clear
    ctx.clearRect(0, 0, W, H);

    // ── Draw parent-child connections ──
    ctx.lineWidth = 1.5;
    for (const node of nodes) {
      if (node.creature.parent1) {
        const parent = nodes.find(
          (n) => n.creature.address === node.creature.parent1
        );
        if (parent) {
          ctx.beginPath();
          ctx.strokeStyle = "rgba(17,17,17,0.08)";
          ctx.moveTo(parent.x, parent.y);
          ctx.lineTo(node.x, node.y);
          ctx.stroke();
        }
      }
    }

    // ── Update & draw nodes ──
    for (const node of nodes) {
      // Simple repulsion from other nodes
      for (const other of nodes) {
        if (other === node) continue;
        const dx = node.x - other.x;
        const dy = node.y - other.y;
        const dist = Math.sqrt(dx * dx + dy * dy) || 1;
        const minDist = node.radius + other.radius + 8;
        if (dist < minDist) {
          const force = ((minDist - dist) / dist) * 0.05;
          node.vx += dx * force;
          node.vy += dy * force;
        }
      }

      // Gravity toward center
      const cx = W / 2 - node.x;
      const cy = H / 2 - node.y;
      node.vx += cx * 0.0003;
      node.vy += cy * 0.0003;

      // Damping
      node.vx *= 0.97;
      node.vy *= 0.97;

      // Move
      node.x += node.vx;
      node.y += node.vy;

      // Keep in bounds
      node.x = Math.max(node.radius, Math.min(W - node.radius, node.x));
      node.y = Math.max(node.radius, Math.min(H - node.radius, node.y));

      // Pulse
      const pulse = 1 + Math.sin(time * 2 + node.pulsePhase) * 0.04;
      const r = node.radius * pulse;

      const isHovered = hoveredRef.current === node;

      // Glow
      if (isHovered) {
        ctx.beginPath();
        const glow = ctx.createRadialGradient(
          node.x, node.y, r * 0.5,
          node.x, node.y, r * 2
        );
        glow.addColorStop(0, node.color + "40");
        glow.addColorStop(1, "transparent");
        ctx.fillStyle = glow;
        ctx.arc(node.x, node.y, r * 2, 0, Math.PI * 2);
        ctx.fill();
      }

      // Main circle
      ctx.beginPath();
      ctx.arc(node.x, node.y, r, 0, Math.PI * 2);
      ctx.fillStyle = node.color;
      ctx.fill();
      ctx.strokeStyle = "#111";
      ctx.lineWidth = isHovered ? 4 : 3;
      ctx.stroke();

      // Generation label
      ctx.fillStyle = "#111";
      ctx.font = `bold ${Math.max(10, r * 0.45)}px 'Space Grotesk', sans-serif`;
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";
      ctx.fillText(`G${node.creature.generation}`, node.x, node.y);
    }

    animRef.current = requestAnimationFrame(draw);
  }, []);

  useEffect(() => {
    animRef.current = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(animRef.current);
  }, [draw]);

  // ── Mouse interaction ──────────────────────────────────────
  const handleMouseMove = useCallback(
    (e: React.MouseEvent<HTMLCanvasElement>) => {
      const canvas = canvasRef.current;
      if (!canvas) return;
      const rect = canvas.getBoundingClientRect();
      const mx = e.clientX - rect.left;
      const my = e.clientY - rect.top;

      let found: Node | null = null;
      for (const node of nodesRef.current) {
        const dx = mx - node.x;
        const dy = my - node.y;
        if (dx * dx + dy * dy < node.radius * node.radius) {
          found = node;
          break;
        }
      }
      hoveredRef.current = found;
      canvas.style.cursor = found ? "pointer" : "default";
    },
    []
  );

  const handleClick = useCallback(
    (e: React.MouseEvent<HTMLCanvasElement>) => {
      const canvas = canvasRef.current;
      if (!canvas) return;
      const rect = canvas.getBoundingClientRect();
      const mx = e.clientX - rect.left;
      const my = e.clientY - rect.top;

      for (const node of nodesRef.current) {
        const dx = mx - node.x;
        const dy = my - node.y;
        if (dx * dx + dy * dy < node.radius * node.radius) {
          openInspector(node.creature);
          return;
        }
      }
    },
    [openInspector]
  );

  return (
    <canvas
      ref={canvasRef}
      className="w-full h-[300px] sm:h-[400px] lg:h-[500px] rounded-nb"
      onMouseMove={handleMouseMove}
      onClick={handleClick}
    />
  );
}
